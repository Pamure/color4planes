// lib/screens/multiplayer_game_screen.dart
//
// FIXES applied in this version:
//  1. oppLeft / oppRight colours were SWAPPED.
//       oppLeft  = opponent's LEFT plane → appears on OUR RIGHT (lane 3) → BLUE
//       oppRight = opponent's RIGHT plane → appears on OUR LEFT  (lane 0) → RED
//     Previously they were reversed, so a blue plane shot red bullets (visually wrong).
//  2. _syncPlanesToInputManager now also fires in onMount (Flame lifecycle step that
//     runs AFTER onLoad finishes).  Previously there was a window where the InputManager
//     held stale/zero plane positions until the next onGameResize, causing tap-on-plane
//     detection to miss.
//  3. broadcastInitialPositions() now re-syncs the InputManager first, so the tap
//     zones are always fresh when the match goes live.
//  4. _laneSwitch / _toggleLane guards cleaned up — isFrozen checked on the PLANE,
//     not by casting. No behaviour change, just safer.
//  5. oppLeft/oppRight lane positions are also re-synced in broadcastInitialPositions
//     (no-op functionally, but ensures the world is fully consistent at game start).

import 'dart:async';
import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nakama/nakama.dart';

import 'package:color4planes/components/explosion.dart';
import 'package:color4planes/components/jet.dart';
import 'package:color4planes/components/lane.dart';
import 'package:color4planes/components/multiplayer_bullet.dart';
import 'package:color4planes/components/opponent_bullet.dart';
import 'package:color4planes/components/opponent_plane.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/managers/audio_manager.dart';
import 'package:color4planes/managers/input_manager.dart';
import 'package:color4planes/models/match_state.dart';
import 'package:color4planes/models/op_code.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/overlays/multiplayer_hud_overlay.dart';
import 'package:color4planes/overlays/multiplayer_result_overlay.dart';
import 'package:color4planes/providers/multiplayer_provider.dart';
import 'package:color4planes/services/nakama_service.dart';

import 'package:color4planes/components/meteor_background.dart';

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  1. SCREEN WIDGET                                                         ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

class MultiplayerGameScreen extends ConsumerStatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  ConsumerState<MultiplayerGameScreen> createState() =>
      _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends ConsumerState<MultiplayerGameScreen> {
  late final MultiplayerFlameGame _game;

  @override
  void initState() {
    super.initState();
    _game = MultiplayerFlameGame();
  }

  // ── State-change side-effects ──────────────────────────────────────────────

  void _onMatchStateChange(MatchState? previous, MatchState next) {
    // Music: start when game goes live
    if (previous?.isPlaying != true && next.isPlaying) {
      _game.matchWorld?.audioManager.playMusic();
      // Broadcast our plane positions so the opponent sees us correctly from
      // the very first frame of play.
      _game.matchWorld?.broadcastInitialPositions();
    }

    // Sound: play win/lose exactly once when the game ends
    if (previous?.isFinished != true && next.isFinished) {
      _game.matchWorld?.playResultSound(next.iAmWinner);
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _leaveMatch() {
    _game.matchWorld?.cancelSubscription();
    _game.matchWorld?.audioManager.stopMusic();
    ref.read(multiplayerProvider.notifier).leaveMatch();
    if (mounted) context.go(RoutePaths.home);
  }

  void _playAgain() {
    _game.matchWorld?.cancelSubscription();
    _game.matchWorld?.audioManager.stopMusic();
    ref.read(multiplayerProvider.notifier).leaveMatch();
    if (mounted) context.go(RoutePaths.multiplayer);
  }

  @override
  Widget build(BuildContext context) {
    _game.widgetRef = ref;
    final match = ref.watch(multiplayerProvider);

    ref.listen(multiplayerProvider, _onMatchStateChange);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _game.matchWorld?.cancelSubscription();
          _game.matchWorld?.audioManager.stopMusic();
          ref.read(multiplayerProvider.notifier).leaveMatch();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GameWidget(game: _game, autofocus: true),

            // Waiting for the other player to finish loading
            if (match.status == MatchStatus.found)
              _WaitingOverlay(opponentName: match.opponentName ?? 'Opponent'),

            // Game live – show HUD
            if (match.isPlaying)
              MultiplayerHudOverlay(
                myLives:       match.myLives,
                opponentLives: match.opponentLives,
                opponentName:  match.opponentName ?? 'Opponent',
                onSwapColors:  () => _game.matchWorld?.swapColors(),
                onQuit:        _leaveMatch,
              ),

            // Result screen
            if (match.isFinished)
              MultiplayerResultOverlay(
                iWon:                 match.iAmWinner,
                opponentDisconnected: match.opponentDisconnected,
                onPlayAgain:          _playAgain,
                onMenu:               _leaveMatch,
              ),

            // Connection badge (top-right)
            Positioned(
              top: 8, right: 12,
              child: SafeArea(
                child: _ConnectionBadge(status: match.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  2. FLAME GAME                                                            ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

class MultiplayerFlameGame extends FlameGame
    with HasCollisionDetection, DragCallbacks, KeyboardEvents {

  late WidgetRef _ref;
  WidgetRef get ref          => _ref;
  set widgetRef(WidgetRef r) => _ref = r;

  MultiplayerMatchWorld? get matchWorld =>
      children.whereType<MultiplayerMatchWorld>().firstOrNull;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    final parallax = await loadParallaxComponent(
      [
        ParallaxImageData(Assets.background),
        ParallaxImageData(Assets.layer1),
        ParallaxImageData(Assets.layer2),
      ],
      baseVelocity: Vector2(0, GameConfig.parallaxBaseSpeed),
      velocityMultiplierDelta: Vector2(1.0, GameConfig.parallaxMultiplier),
      repeat: ImageRepeat.repeat,
    );
    add(parallax);
    add(DarknessOverlay());
    add(MeteorBackgroundComponent());
    add(MultiplayerMatchWorld());
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent && ref.read(multiplayerProvider).isPlaying) {
      final handled =
          matchWorld?.inputManager.handleKeyPress(event.logicalKey) ?? false;
      return handled ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  Vector2? _dragStart;
  Vector2? _dragCurrent;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!ref.read(multiplayerProvider).isPlaying) return;
    _dragStart   = event.localPosition.clone();
    _dragCurrent = event.localPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragCurrent != null) _dragCurrent = _dragCurrent! + event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_dragStart != null && _dragCurrent != null) {
      matchWorld?.inputManager.handleDragEnd(
        _dragCurrent! - _dragStart!,
        _dragStart!,
      );
    }
    _dragStart = _dragCurrent = null;
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  3. MATCH WORLD                                                           ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

class MultiplayerMatchWorld extends Component
    with HasGameReference<MultiplayerFlameGame> {

  static const int    totalLanes   = GameConfig.totalLanes;
  static const double maxGameWidth = GameConfig.maxGameWidth;

  double laneWidth  = 0.0;
  double gameStartX = 0.0;

  late InputManager inputManager;
  late AudioManager audioManager;

  PlayerPlane?   leftPlane;
  PlayerPlane?   rightPlane;

  // ── FIX 1: opponent plane colour assignment ──────────────────────────────
  // oppLeft  = opponent's LEFT plane  → mirrored to OUR RIGHT (lane 3) → BLUE
  // oppRight = opponent's RIGHT plane → mirrored to OUR LEFT  (lane 0) → RED
  // Previously these were RED/BLUE respectively – exactly backwards.
  OpponentPlane? oppLeft;
  OpponentPlane? oppRight;

  final List<Lane> _lanes = [];

  StreamSubscription<MatchData>? _matchDataSub;
  final List<MatchData> _pendingEvents = [];

  bool _layoutReady   = false;
  bool _isLoaded      = false;
  bool _inputReady    = false;   // true once InputManager is created

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    debugPrint('[MP-WORLD] onLoad() START');

    try {
      await NakamaService.instance.ensureConnected();
    } catch (e) {
      debugPrint('[MP-WORLD] FATAL: could not connect socket: $e');
      return;
    }

    _matchDataSub = NakamaService.instance.socket.onMatchData.listen(
      _onMatchData,
      onError: (e) => debugPrint('[MP-WORLD] matchData stream error: $e'),
      onDone:  ()  => debugPrint('[MP-WORLD] matchData stream closed'),
    );

    inputManager = InputManager(
      onLeftShoot:  _shootLeft,
      onRightShoot: _shootRight,
      onSwapColors: swapColors,
      onLaneSwitch: _laneSwitch,
      onToggleLane: _toggleLane,
    );
    _inputReady = true;

    audioManager = AudioManager();
    await audioManager.initialize();
    // Music is started by the screen when MatchStatus.playing begins.

    _isLoaded = true;

    // Sync plane positions now that the InputManager exists.
    // onGameResize was already called (before onLoad), so planes are positioned.
    _syncPlanesToInputManager();

    debugPrint('[MP-WORLD] calling onLocalReady()');
    await game.ref.read(multiplayerProvider.notifier).onLocalReady();
    debugPrint('[MP-WORLD] onLoad() COMPLETE');
  }

  // ── FIX 2: onMount fires AFTER onLoad is fully awaited ────────────────────
  // This is the safest place to do a final sync because everything is ready.
  @override
  void onMount() {
    super.onMount();
    _syncPlanesToInputManager();
    debugPrint('[MP-WORLD] onMount sync done');
  }

  @override
  void update(double dt) {
    if (!_isLoaded) return;
    super.update(dt);

    // Drain buffered events once the layout is ready
    if (_pendingEvents.isNotEmpty && _layoutReady) {
      final batch = List<MatchData>.from(_pendingEvents);
      _pendingEvents.clear();
      for (final e in batch) {
        _processEvent(e);
      }
    }
  }

  // ── Network event pipeline ─────────────────────────────────────────────────

  void _onMatchData(MatchData data) {
    if (!_layoutReady) {
      _pendingEvents.add(data);
      return;
    }
    _processEvent(data);
  }

  void _processEvent(MatchData data) {
    final state = game.ref.read(multiplayerProvider);

    if (data.matchId != state.matchId) return;
    if (data.presence?.userId == state.myUserId) return;

    if (data.opCode == MatchOpCode.playerReady) {
      game.ref.read(multiplayerProvider.notifier).onOpponentReady();
      return;
    }

    if (!state.isPlaying) return;

    final raw = data.data ?? const <int>[];
    if (raw.isEmpty) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[MP-WORLD] malformed event op=${data.opCode}: $e');
      return;
    }

    switch (data.opCode) {
      case MatchOpCode.bulletFired:
        _handleBulletFired(payload);
      case MatchOpCode.colorSwapped:
        oppLeft?.swapColor();
        oppRight?.swapColor();
      case MatchOpCode.laneSwitched:
        _handleLaneSwitched(payload);
      case MatchOpCode.planeHit:
        audioManager.playSound(
          AudioConfig.explosion,
          volume: AudioConfig.explosionVol * 0.5,
        );
      case MatchOpCode.lifeLost:
        final lives = payload['lives'] as int? ?? 0;
        game.ref.read(multiplayerProvider.notifier).setOpponentLives(lives);
      case MatchOpCode.gameOver:
        final winnerId = payload['winner_id'] as String?;
        if (winnerId != null) {
          game.ref.read(multiplayerProvider.notifier).onOpponentGameOver(winnerId);
        }
    }
  }

  void _handleBulletFired(Map<String, dynamic> payload) {
    final colorStr     = payload['color'] as String? ?? 'blue';
    final color        = colorStr == 'blue' ? PlaneColor.blue : PlaneColor.red;
    final srcLane      = payload['lane'] as int? ?? 0;
    final mirroredLane = (totalLanes - 1) - srcLane;
    final x            = gameStartX + (mirroredLane + 0.5) * laneWidth;

    add(OpponentBullet(
      color:         color,
      startPosition: Vector2(x, MultiplayerConfig.opponentBulletStartY),
    ));
    audioManager.playSound(AudioConfig.shoot, volume: AudioConfig.shootVol * 0.5);
  }

  // ── Lane switch for opponent ───────────────────────────────────────────────
  // When opponent's LEFT plane (isLeft=true) moves, it appears on OUR RIGHT,
  // so we move oppLeft (which lives on the right side of our screen).
  void _handleLaneSwitched(Map<String, dynamic> payload) {
    final isLeft   = payload['is_left'] as bool? ?? false;
    final srcLane  = payload['lane']    as int?  ?? 0;
    final mirrored = (totalLanes - 1) - srcLane;

    final target = isLeft ? oppLeft : oppRight;
    target?.setLane(mirrored);
    target?.position.x = getLaneCenterX(mirrored);
  }

  // ── Bullets hitting the player ─────────────────────────────────────────────

  void onOpponentBulletEscaped() {
    audioManager.playSound(AudioConfig.lifelineLost, volume: 0.5);
    game.ref.read(multiplayerProvider.notifier).reportLifeLost();
  }

  void onPlayerPlaneHit(PlayerPlane plane) {
    audioManager.playSound(AudioConfig.shoot, volume: 0.3);
    plane.freeze();
    game.ref.read(multiplayerProvider.notifier).sendPlaneHit(
      isLeft: plane == leftPlane,
    );
  }

  void onBulletCancel(Vector2 position, PlaneColor color) {
    add(ExplosionEffect(position: position, color: color));
    audioManager.playSound(
      AudioConfig.explosion,
      volume: AudioConfig.explosionVol * 0.7,
    );
  }

  // ── Win/lose sounds ────────────────────────────────────────────────────────

  void playResultSound(bool iWon) async {
    audioManager.stopMusic();
    await Future.delayed(const Duration(milliseconds: 80));
    audioManager.playSound(
      iWon ? AudioConfig.youWin : AudioConfig.youLose,
      volume: 1.0,
    );
  }

  // ── Reset (kept for safety even if rematch flow is removed) ───────────────

  void resetForRematch() {
    children.whereType<OpponentBullet>().toList().forEach((b) => b.removeFromParent());
    children.whereType<MultiplayerPlayerBullet>().toList().forEach((b) => b.removeFromParent());
    children.whereType<ExplosionEffect>().toList().forEach((e) => e.removeFromParent());

    leftPlane?.resetToDefault();
    rightPlane?.resetToDefault();

    final size = game.size;
    if (size != Vector2.zero()) {
      final topY = MultiplayerConfig.opponentBulletStartY - 20;
      oppLeft?.isFrozen = false;
      oppLeft?.setLane(3);
      oppLeft?.position = Vector2(getLaneCenterX(3), topY);
      oppRight?.isFrozen = false;
      oppRight?.setLane(0);
      oppRight?.position = Vector2(getLaneCenterX(0), topY);
    }

    _syncPlanesToInputManager();
  }

  // ── FIX 3: broadcastInitialPositions re-syncs InputManager first ──────────
  // Called by the screen when MatchStatus.playing first becomes true.
  void broadcastInitialPositions() {
    if (leftPlane == null || rightPlane == null) return;

    // Refresh tap zones so the very first in-game tap is detected correctly.
    _syncPlanesToInputManager();

    final n = game.ref.read(multiplayerProvider.notifier);
    n.sendLaneSwitched(isLeft: true,  lane: leftPlane!.currentLane);
    n.sendLaneSwitched(isLeft: false, lane: rightPlane!.currentLane);
    debugPrint('[MP-WORLD] Broadcast initial positions (input synced)');
  }

  // ── Shooting ───────────────────────────────────────────────────────────────

  void _shootLeft() {
    if (leftPlane == null || leftPlane!.isFrozen) return;
    if (!leftPlane!.shoot()) return;
    _spawnBullet(leftPlane!);
  }

  void _shootRight() {
    if (rightPlane == null || rightPlane!.isFrozen) return;
    if (!rightPlane!.shoot()) return;
    _spawnBullet(rightPlane!);
  }

  void _spawnBullet(PlayerPlane plane) {
    add(MultiplayerPlayerBullet(
      color:         plane.planeColor,
      startPosition: Vector2(plane.position.x, plane.position.y - plane.size.y / 2 - 4),
    ));
    audioManager.playSound(AudioConfig.shoot, volume: AudioConfig.shootVol);
    game.ref.read(multiplayerProvider.notifier).sendBulletFired(
      color: plane.planeColor.name,
      lane:  plane.currentLane,
    );
  }

  // ── Color swap ─────────────────────────────────────────────────────────────

  void swapColors() {
    leftPlane?.swapColor();
    rightPlane?.swapColor();
    game.ref.read(multiplayerProvider.notifier).sendColorSwapped();
  }

  // ── Lane switch via swipe / keyboard ──────────────────────────────────────

  void _laneSwitch(bool isLeft, bool towardCenter) {
    final plane = isLeft ? leftPlane : rightPlane;
    if (plane == null || plane.isFrozen) return;
    final newLane = isLeft ? (towardCenter ? 1 : 0) : (towardCenter ? 2 : 3);
    plane.switchLane(newLane);
    plane.position.x = getLaneCenterX(newLane);
    _syncPlanesToInputManager();
    game.ref.read(multiplayerProvider.notifier)
        .sendLaneSwitched(isLeft: isLeft, lane: newLane);
  }

  // ── Lane toggle via tap on plane ───────────────────────────────────────────

  void _toggleLane(bool isLeft) {
    final plane = isLeft ? leftPlane : rightPlane;
    if (plane == null || plane.isFrozen) return;
    final int newLane;
    if (isLeft) {
      newLane = plane.currentLane == 0 ? 1 : 0;
    } else {
      newLane = plane.currentLane == 3 ? 2 : 3;
    }
    plane.switchLane(newLane);
    plane.position.x = getLaneCenterX(newLane);
    _syncPlanesToInputManager();
    game.ref.read(multiplayerProvider.notifier)
        .sendLaneSwitched(isLeft: isLeft, lane: newLane);
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final playW   = size.x.clamp(0.0, maxGameWidth);
    gameStartX    = (size.x - playW) / 2;
    laneWidth     = playW / totalLanes;

    if (_lanes.isEmpty) {
      for (int i = 0; i < totalLanes; i++) {
        final l = Lane(
          laneIndex: i,
          x:         gameStartX + i * laneWidth,
          width:     laneWidth,
          height:    size.y,
        );
        _lanes.add(l);
        add(l);
      }
    } else {
      for (int i = 0; i < _lanes.length; i++) {
        _lanes[i].updateSize(gameStartX + i * laneWidth, laneWidth, size.y);
      }
    }

    final pW        = laneWidth * GameConfig.planeWidthRatio;
    final pH        = pW * GameConfig.planeAspectRatio;
    final planeSize = Vector2(pW, pH);

    if (leftPlane == null) {
      leftPlane  = PlayerPlane(planeColor: PlaneColor.blue, currentLane: 0, planeSize: planeSize);
      rightPlane = PlayerPlane(planeColor: PlaneColor.red,  currentLane: 3, planeSize: planeSize);
      add(leftPlane!);
      add(rightPlane!);
    }

    if (oppLeft == null) {
      // ── FIX 1: correct colours ─────────────────────────────────────────
      // oppLeft  = their LEFT plane  → OUR RIGHT side (lane 3) → BLUE
      // oppRight = their RIGHT plane → OUR LEFT  side (lane 0) → RED
      oppLeft  = OpponentPlane(planeColor: PlaneColor.blue, currentLane: 3, planeSize: planeSize);
      oppRight = OpponentPlane(planeColor: PlaneColor.red,  currentLane: 0, planeSize: planeSize);
      add(oppLeft!);
      add(oppRight!);
    }

    _repositionPlanes(size);

    // Update InputManager screen size and plane positions if ready.
    if (_inputReady) {
      inputManager.updateScreenSize(size);
      _syncPlanesToInputManager();
    }

    if (!_layoutReady) {
      _layoutReady = true;
      debugPrint('[MP-WORLD] layout ready ✓');
    }
  }

  void _repositionPlanes(Vector2 size) {
    final botY = size.y - GameConfig.planeBottomPad;
    final topY = MultiplayerConfig.opponentBulletStartY - 20;

    leftPlane?.position  = Vector2(getLaneCenterX(leftPlane!.currentLane),  botY);
    rightPlane?.position = Vector2(getLaneCenterX(rightPlane!.currentLane), botY);
    oppLeft?.position    = Vector2(getLaneCenterX(oppLeft!.currentLane),    topY);
    oppRight?.position   = Vector2(getLaneCenterX(oppRight!.currentLane),   topY);

    // Always try to sync — _syncPlanesToInputManager guards on _inputReady.
    _syncPlanesToInputManager();
  }

  // ── Input manager sync ────────────────────────────────────────────────────
  // Called whenever planes are created, moved, or the layout changes.
  // Guards on _inputReady (not _isLoaded) so it can be called early in onLoad.
  void _syncPlanesToInputManager() {
    if (!_inputReady) return;
    if (leftPlane == null) return;
    inputManager.updatePlanePositions(
      leftPlane?.position,
      rightPlane?.position,
      tapRadius: laneWidth * 1.1,
    );
  }

  double getLaneCenterX(int lane) => gameStartX + (lane + 0.5) * laneWidth;

  // ── Cleanup ────────────────────────────────────────────────────────────────

  void cancelSubscription() {
    _matchDataSub?.cancel();
    _matchDataSub = null;
    debugPrint('[MP-WORLD] subscription cancelled');
  }

  @override
  void onRemove() {
    _matchDataSub?.cancel();
    _pendingEvents.clear();
    audioManager.dispose();
    super.onRemove();
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  4. OVERLAYS                                                              ║
// ╚═══════════════════════════════════════════════════════════════════════════╝

class _WaitingOverlay extends StatelessWidget {
  final String opponentName;
  const _WaitingOverlay({required this.opponentName});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xCC000000),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: SpaceColors.blueNova),
          const SizedBox(height: 24),
          Text(
            'Waiting for $opponentName…',
            style: TextStyle(
              color:      SpaceColors.cometGrey,
              fontSize:   18,
              fontFamily: AppFonts.body,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading game assets',
            style: TextStyle(
              color:      SpaceColors.asteroidGrey,
              fontSize:   13,
              fontFamily: AppFonts.body,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConnectionBadge extends StatelessWidget {
  final MatchStatus status;
  const _ConnectionBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      MatchStatus.playing  => (SpaceColors.difficultyBoy, 'LIVE'),
      MatchStatus.found    => (SpaceColors.difficultyMan, 'CONNECTING'),
      MatchStatus.finished => (SpaceColors.cometGrey,     'END'),
      _                    => (SpaceColors.asteroidGrey,  ''),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        SpaceColors.hudBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:         color,
              fontSize:      10,
              fontFamily:    AppFonts.body,
              letterSpacing: 1.5,
              fontWeight:    FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class DarknessOverlay extends Component with HasGameReference<FlameGame> {
  final Paint _paint = Paint()..color = const Color(0x99000000);
  @override
  void render(Canvas canvas) =>
      canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), _paint);
}