// lib/screens/game_screen.dart

import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/components/alien_ship.dart';
import 'package:color4planes/components/bullet.dart';
import 'package:color4planes/components/explosion.dart';
import 'package:color4planes/components/game_timer.dart';
import 'package:color4planes/components/jet.dart';
import 'package:color4planes/components/lane.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/managers/audio_manager.dart';
import 'package:color4planes/managers/difficulty_manager.dart';
import 'package:color4planes/managers/input_manager.dart';
import 'package:color4planes/managers/spawn_manager.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/overlays/game_over_overlay.dart';
import 'package:color4planes/overlays/hud_overlay.dart';
import 'package:color4planes/overlays/pause_overlay.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/providers/game_provider.dart';
import 'package:color4planes/providers/settings_provider.dart'; // FIX: was missing


import 'package:color4planes/components/meteor_background.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late FlameView _game;

  @override
  void initState() {
    super.initState();
    _game = FlameView();
    Future.microtask(() {
      if (mounted) ref.read(gameSessionProvider.notifier).startGame();
    });
  }

  void _pause() {
    _game.pauseEngine();
    ref.read(gameSessionProvider.notifier).pause();
  }

  void _resume() {
    _game.resumeEngine();
    ref.read(gameSessionProvider.notifier).resume();
  }

  void _restart() {
    _game.mainView?.restartGame();
    ref.read(gameSessionProvider.notifier).startGame();
    _game.resumeEngine();
  }

  void _mainMenu() {
    _game.audio?.stopMusic();
    _game.resumeEngine();
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    _game.widgetRef = ref;

    final gameState = ref.watch(gameSessionProvider);
    final user      = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(game: _game),

          if (gameState.status == GameStatus.countdown)
            _SinglePlayerCountdownOverlay(seconds: gameState.countdownSeconds),

          if (gameState.isPlaying)
            HUDOverlay(
              onSwapColors: () => _game.mainView?.swapColors(),
              onPause:      _pause,
            ),

          if (gameState.status == GameStatus.paused)
            PauseOverlay(
              onResume:   _resume,
              onMainMenu: _mainMenu,
            ),

          if (gameState.status == GameStatus.gameOver)
            GameOverOverlay(
              summary:    gameState.summary,
              highScore:  user?.highScore ?? 0,
              onRestart:  _restart,
              onMainMenu: _mainMenu,
            ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// FLAME VIEW
// ─────────────────────────────────────────────────────────────────────────────

class FlameView extends FlameGame
    with HasCollisionDetection,
         KeyboardEvents,
         DragCallbacks {

  late WidgetRef _widgetRef;
  WidgetRef get ref          => _widgetRef;
  set widgetRef(WidgetRef r) => _widgetRef = r;

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
    
    add(MainView());
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (ref.read(gameSessionProvider).status != GameStatus.playing) {
        return KeyEventResult.ignored;
      }
      final handled = mainView?.inputManager.handleKeyPress(event.logicalKey) ?? false;
      return handled ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  Vector2? _dragStart;
  Vector2? _dragCurrent;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (ref.read(gameSessionProvider).status != GameStatus.playing) return;
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
      mainView?.inputManager.handleDragEnd(
        _dragCurrent! - _dragStart!,
        _dragStart!,
      );
    }
    _dragStart = _dragCurrent = null;
  }

  MainView?     get mainView        => children.whereType<MainView>().firstOrNull;
  double        get scoreMultiplier => mainView?.difficultyManager.scoreMultiplier ?? 1.0;
  AudioManager? get audio           => mainView?.audioManager;
}


// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class MainView extends Component with HasGameReference<FlameView> {

  static const int    totalLanes   = GameConfig.totalLanes;
  static const double maxGameWidth = GameConfig.maxGameWidth;

  double laneWidth  = 0;
  double gameStartX = 0;

  late DifficultyManager difficultyManager;
  late SpawnManager      spawnManager;
  late InputManager      inputManager;
  late AudioManager      audioManager;

  bool _isLoaded = false;

  final List<Lane> _lanes = [];
  PlayerPlane?     leftPlane;
  PlayerPlane?     rightPlane;

  double _survivalTime = 0;
  int    _shotCount    = 0;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    difficultyManager = DifficultyManager();

    spawnManager = SpawnManager(
      difficultyManager: difficultyManager,
      gameWorld:         this,
    );

    inputManager = InputManager(
      onLeftShoot:  _shootLeft,
      onRightShoot: _shootRight,
      onSwapColors: swapColors,
      onLaneSwitch: _handleLaneSwitch,
      onToggleLane: _toggleLane,
    );

    audioManager = AudioManager();
    await audioManager.initialize();
    audioManager.playMusic();

    add(GameTimerDisplay(getTime: () => _survivalTime));

    _isLoaded = true;

    if (laneWidth != 0) {
      spawnManager.updateDimensions(
        width: game.size.x, height: game.size.y,
        startX: gameStartX, laneW: laneWidth,
      );
      inputManager.updateScreenSize(game.size);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final status = game.ref.read(gameSessionProvider).status;
    if (status != GameStatus.playing) return;
    _survivalTime += dt;
    difficultyManager.update(dt);
    spawnManager.update(dt);

    // Sync ambient space speed with difficulty
    final parallax = game.children.whereType<ParallaxComponent>().firstOrNull;
    if (parallax != null) {
      parallax.parallax?.baseVelocity = Vector2(0, difficultyManager.enemySpeed * 0.35);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final playableW = size.x.clamp(0.0, maxGameWidth);
    gameStartX = (size.x - playableW) / 2;
    laneWidth  = playableW / totalLanes;

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

    if (leftPlane == null) {
      final pW = laneWidth * GameConfig.planeWidthRatio;
      final pH = pW * GameConfig.planeAspectRatio;
      leftPlane  = PlayerPlane(planeColor: PlaneColor.blue, currentLane: 0, planeSize: Vector2(pW, pH));
      rightPlane = PlayerPlane(planeColor: PlaneColor.red,  currentLane: 3, planeSize: Vector2(pW, pH));
      add(leftPlane!);
      add(rightPlane!);
    }
    _positionPlanes(size); // FIX: was _positionplanes

    if (_isLoaded) {
      spawnManager.updateDimensions(
        width: size.x, height: size.y,
        startX: gameStartX, laneW: laneWidth,
      );
      inputManager.updateScreenSize(size);
      _syncPlanesToInputManager();
    }
  }

  void onShipDestroyedAt(Vector2 position, PlaneColor color, int basePoints) {
    add(ExplosionEffect(position: position.clone(), color: color));
    final n = game.ref.read(gameSessionProvider.notifier);
    n.addScore(basePoints, difficultyManager.scoreMultiplier);
    n.recordShipDestroyed();
    spawnManager.onShipDestroyed();
    audioManager.playSound(AudioConfig.explosion, volume: AudioConfig.explosionVol);
  }

  void onGameOver() {
    game.pauseEngine();
    game.ref.read(gameSessionProvider.notifier).triggerGameOver(
      survivedFor:   _formatTime(_survivalTime),
      shotsFired:    _shotCount,
      secondsPlayed: _survivalTime,
    );
    audioManager.playSound(AudioConfig.gameOver, volume: AudioConfig.gameOverVol);
    audioManager.stopMusic();
  }

  // ── Shooting ──────────────────────────────────────────────────────────────
  void _shootLeft() {
    if (leftPlane != null && leftPlane!.shoot()) { _spawnBullet(leftPlane!);  _shotCount++; }
  }

  void _shootRight() {
    if (rightPlane != null && rightPlane!.shoot()) { _spawnBullet(rightPlane!); _shotCount++; }
  }

  void _spawnBullet(PlayerPlane plane) {
    add(Bullet(
      color:         plane.planeColor,
      startPosition: Vector2(plane.position.x, plane.position.y - plane.size.y / 2),
    ));
    audioManager.playSound(AudioConfig.shoot, volume: AudioConfig.shootVol);
  }

  // ── Color swap ────────────────────────────────────────────────────────────
  void swapColors() {
    leftPlane?.swapColor();
    rightPlane?.swapColor();
  }

  // ── Lane switch via swipe or keyboard ─────────────────────────────────────
  void _handleLaneSwitch(bool isLeft, bool moveTowardCenter) {
    final plane = isLeft ? leftPlane : rightPlane;
    if (plane == null) return;
    final newLane = isLeft
        ? (moveTowardCenter ? 1 : 0)
        : (moveTowardCenter ? 2 : 3);
    plane.switchLane(newLane);
    plane.position.x = getLaneCenterX(newLane); // FIX: was getlanecenterx
    _syncPlanesToInputManager();
  }

  // ── Lane toggle via tap on plane ──────────────────────────────────────────
  void _toggleLane(bool isLeft) {
    final plane = isLeft ? leftPlane : rightPlane;
    if (plane == null) return;

    final int newLane;
    if (isLeft) {
      newLane = plane.currentLane == 0 ? 1 : 0;
    } else {
      newLane = plane.currentLane == 3 ? 2 : 3;
    }

    plane.switchLane(newLane);
    plane.position.x = getLaneCenterX(newLane); // FIX: was getlanecenterx
    _syncPlanesToInputManager();
  }

  // ── Restart ───────────────────────────────────────────────────────────────
  void restartGame() {
    children.whereType<Bullet>().toList().forEach((b) => b.removeFromParent());
    children.whereType<AlienShip>().toList().forEach((s) => s.destroy());
    children.whereType<ExplosionEffect>().toList().forEach((e) => e.removeFromParent());
    difficultyManager.reset();
    spawnManager.reset();
    leftPlane?.resetToDefault();
    rightPlane?.resetToDefault();
    _survivalTime = 0;
    _shotCount    = 0;

    // Read live settings — respects whatever the user set in the settings screen
    final settings = game.ref.read(settingsProvider); // FIX: import was missing
    audioManager.setMusicEnabled(settings.musicEnabled);
    audioManager.setSfxEnabled(settings.sfxEnabled);
    audioManager.stopMusic();
    audioManager.playMusic();

    _syncPlanesToInputManager();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // FIX: was getlanecenterx — Dart is case-sensitive, lowercase ≠ camelCase
  double getLaneCenterX(int lane) => gameStartX + (lane + 0.5) * laneWidth;

  // FIX 1: was _positionplanes — wrong casing on method name
  // FIX 2: was vector2 — Dart class names are PascalCase, not lowercase
  void _positionPlanes(Vector2 size) {
    if (leftPlane == null || rightPlane == null) return;
    final y = size.y - GameConfig.planeBottomPad;
    leftPlane!.position  = Vector2(getLaneCenterX(leftPlane!.currentLane),  y);
    rightPlane!.position = Vector2(getLaneCenterX(rightPlane!.currentLane), y);
    _syncPlanesToInputManager();
  }

  void _syncPlanesToInputManager() {
    if (!_isLoaded) return;
    inputManager.updatePlanePositions(
      leftPlane?.position,
      rightPlane?.position,
      tapRadius: laneWidth * 0.85,
    );
  }

  String _formatTime(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class DarknessOverlay extends Component with HasGameReference<FlameGame> {
  final Paint _paint = Paint()..color = const Color(0x99000000); // 60% black
  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), _paint);
  }
}

class _SinglePlayerCountdownOverlay extends StatelessWidget {
  final int seconds;
  const _SinglePlayerCountdownOverlay({required this.seconds});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0x66000000),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key:   ValueKey(seconds),
              seconds > 0 ? '$seconds' : 'GO!',
              style: TextStyle(
                color:      seconds > 0 ? Colors.white : Colors.greenAccent,
                fontSize:   96,
                fontWeight: FontWeight.bold,
                fontFamily: AppFonts.title,
                shadows: const [Shadow(blurRadius: 20, color: Colors.black)],
              ),
            ),
          ),
        ),
      );
}
