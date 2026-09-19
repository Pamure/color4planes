// lib/screens/multiplayer_lobby_screen.dart
//
// FIX: The COPY button inside the "created match" card was showing
// "SEARCHING THE VOID..." as its label (copy-paste error from the status text).
// Corrected to "COPY".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/match_state.dart';
import 'package:color4planes/providers/multiplayer_provider.dart';
import 'package:color4planes/widgets/starfield_background.dart';

class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyState();
}

class _MultiplayerLobbyState extends ConsumerState<MultiplayerLobbyScreen> {
  final _matchIdCtrl = TextEditingController();
  String? _createdMatchId;
  String? _privateError;
  bool _joiningPrivate = false;

  @override
  void dispose() {
    _matchIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPrivate() async {
    setState(() { _privateError = null; _createdMatchId = null; });
    final matchId = await ref.read(multiplayerProvider.notifier).createPrivateMatch();
    if (matchId != null) {
      setState(() { _createdMatchId = matchId; });
    } else {
      setState(() { _privateError = 'Could not create match'; });
    }
  }

  Future<void> _joinPrivate() async {
    final id = _matchIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() { _joiningPrivate = true; _privateError = null; });
    final ok = await ref.read(multiplayerProvider.notifier).joinPrivateMatch(id);
    if (!ok) {
      setState(() { _privateError = 'Could not join match — check the ID'; _joiningPrivate = false; });
    } else {
      setState(() { _joiningPrivate = false; });
    }
  }

  Future<void> _cancelWaiting() async {
    await ref.read(multiplayerProvider.notifier).leaveMatch();
    setState(() { _createdMatchId = null; });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied!',
          style: TextStyle(
            color: SpaceColors.starWhite,
            fontFamily: AppFonts.body,
            letterSpacing: 1.5,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(multiplayerProvider);

    ref.listen<MatchState>(multiplayerProvider, (_, next) {
      if (next.status == MatchStatus.countdown ||
          next.status == MatchStatus.playing   ||
          next.status == MatchStatus.found) {
        context.go(RoutePaths.multiplayerGame);
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && (match.status == MatchStatus.searching || match.status == MatchStatus.waitingForFriend)) {
          ref.read(multiplayerProvider.notifier).leaveMatch();
        }
      },
      child: Scaffold(
        body: StarfieldBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      // ── Title ──────────────────────────────────────────────
                      Text(
                        'MULTIPLAYER',
                        style: TextStyle(
                          color:         SpaceColors.starWhite,
                          fontSize:      24,
                          fontFamily:    AppFonts.title,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 8.0,
                          shadows: [Shadow(color: SpaceColors.neonBlue, blurRadius: 16)],
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '3 LIVES  ·  MIRROR BATTLE',
                        style: TextStyle(
                          color:         SpaceColors.asteroidGrey,
                          fontSize:      10,
                          fontFamily:    AppFonts.body,
                          letterSpacing: 4.0,
                        ),
                      ),

                      SizedBox(height: 40),
                      _StatusArea(match: match),
                      SizedBox(height: 40),

                      // ── RANDOM MATCH (only when idle) ─────────────────────
                      if (match.status == MatchStatus.idle || match.status == MatchStatus.searching)
                        SizedBox(
                          width: double.infinity,
                          child: _ActionButton(match: match),
                        ),

                      // ── CANCEL WAITING (when waitingForFriend) ─────────────
                      if (match.status == MatchStatus.waitingForFriend) ...[
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _cancelWaiting,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: SpaceColors.neonRed.withValues(alpha: 0.6)),
                                borderRadius: BorderRadius.circular(4),
                                color: SpaceColors.neonRed.withValues(alpha: 0.12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cancel_rounded, color: SpaceColors.neonRed, size: 18),
                                  SizedBox(width: 8),
                                  Text('CANCEL WAITING', style: TextStyle(
                                    color: SpaceColors.neonRed, fontSize: 12,
                                    fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: 28),

                      // ── PLAY WITH FRIEND (only when idle) ──────────────────
                      if (match.status == MatchStatus.idle) ...[
                        Row(
                          children: [
                            Container(width: 3, height: 14, color: SpaceColors.neonRed),
                            SizedBox(width: 8),
                            Text('PLAY WITH HOMIES', style: TextStyle(
                              color: SpaceColors.cometGrey, fontSize: 11,
                              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                              letterSpacing: 4.0,
                            )),
                          ],
                        ),
                        SizedBox(height: 14),

                        // CREATE button
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _createPrivate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: SpaceColors.sunflare.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(4),
                                color: SpaceColors.sunflare.withValues(alpha: 0.08),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: SpaceColors.sunflare, size: 18),
                                  SizedBox(width: 8),
                                  Text('CREATE PRIVATE MATCH', style: TextStyle(
                                    color: SpaceColors.sunflare, fontSize: 12,
                                    fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Created match ID card
                        if (_createdMatchId != null) ...[
                          SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceColors.sunflare.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(4),
                              color: SpaceColors.hudBackground,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MATCH CODE', style: TextStyle(
                                  color: SpaceColors.asteroidGrey, fontSize: 9,
                                  fontFamily: AppFonts.body, letterSpacing: 2,
                                )),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _createdMatchId!,
                                        style: TextStyle(
                                          color: SpaceColors.sunflare, fontSize: 12,
                                          fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // FIX: was showing "SEARCHING THE VOID..." — now correctly says "COPY"
                                    GestureDetector(
                                      onTap: () => _copyToClipboard(_createdMatchId!, 'Match ID'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: SpaceColors.sunflare.withValues(alpha: 0.5)),
                                          borderRadius: BorderRadius.circular(4),
                                          color: SpaceColors.sunflare.withValues(alpha: 0.1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.copy_rounded, color: SpaceColors.sunflare, size: 12),
                                            SizedBox(width: 4),
                                            Text('COPY', style: TextStyle(
                                              color: SpaceColors.sunflare, fontSize: 9,
                                              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            )),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Waiting for friend to join…',
                                  style: TextStyle(
                                    color: SpaceColors.asteroidGrey, fontSize: 9,
                                    fontFamily: AppFonts.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 12),

                        // JOIN section
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _matchIdCtrl,
                                style: TextStyle(
                                  color: SpaceColors.starWhite, fontSize: 12,
                                  fontFamily: AppFonts.body,
                                ),
                                cursorColor: SpaceColors.neonBlue,
                                decoration: InputDecoration(
                                  hintText: 'Paste friend\'s Match ID...',
                                  hintStyle: TextStyle(color: SpaceColors.faint, fontSize: 10, fontFamily: AppFonts.body),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: SpaceColors.dividerLine),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(color: SpaceColors.neonBlue),
                                  ),
                                  filled: true,
                                  fillColor: SpaceColors.hudBackground,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            GestureDetector(
                              onTap: _joiningPrivate ? null : _joinPrivate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: SpaceColors.neonBlue.withValues(alpha: 0.6)),
                                  borderRadius: BorderRadius.circular(4),
                                  color: SpaceColors.neonBlue.withValues(alpha: 0.12),
                                ),
                                child: _joiningPrivate
                                    ? SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(color: SpaceColors.neonBlue, strokeWidth: 2))
                                    : Text('JOIN', style: TextStyle(
                                        color: SpaceColors.neonBlue, fontSize: 11,
                                        fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      )),
                              ),
                            ),
                          ],
                        ),

                        if (_privateError != null) ...[
                          SizedBox(height: 8),
                          Text(_privateError!, style: TextStyle(
                            color: SpaceColors.neonRed, fontSize: 10,
                            fontFamily: AppFonts.body,
                          )),
                        ],
                      ], // end idle guard

                      SizedBox(height: 28),

                      // ── Back ───────────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () async {
                            if (match.status == MatchStatus.searching) {
                              await ref.read(multiplayerProvider.notifier).cancelMatchmaking();
                            } else if (match.status == MatchStatus.waitingForFriend) {
                              await ref.read(multiplayerProvider.notifier).leaveMatch();
                            }
                            if (context.mounted) context.go(RoutePaths.home);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceColors.asteroidGrey.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded, color: SpaceColors.cometGrey, size: 16),
                                SizedBox(width: 6),
                                Text('BACK', style: TextStyle(
                                  color: SpaceColors.cometGrey, fontSize: 13,
                                  fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                                  letterSpacing: 4.0,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusArea extends StatelessWidget {
  final MatchState match;
  const _StatusArea({required this.match});

  @override
  Widget build(BuildContext context) {
    return switch (match.status) {
      MatchStatus.searching => Column(
        children: [
          SizedBox(
            width: 80, height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PulsingRing(color: SpaceColors.neonBlue, delay: Duration.zero),
                _PulsingRing(color: SpaceColors.neonBlue, delay: const Duration(milliseconds: 500)),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SpaceColors.neonBlue.withValues(alpha: 0.3),
                    border: Border.all(color: SpaceColors.neonBlue, width: 1.5),
                  ),
                  child: Icon(Icons.search_rounded, color: SpaceColors.neonBlue, size: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text('SCANNING FOR OPPONENTS', style: TextStyle(
            color: SpaceColors.starWhite, fontSize: 12,
            fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          )),
          SizedBox(height: 6),
          Text('May take a few seconds', style: TextStyle(
            color: SpaceColors.asteroidGrey, fontSize: 11, fontFamily: AppFonts.body,
          )),
        ],
      ),

      MatchStatus.waitingForFriend => Column(
        children: [
          SizedBox(
            width: 80, height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PulsingRing(color: SpaceColors.sunflare, delay: Duration.zero),
                _PulsingRing(color: SpaceColors.sunflare, delay: const Duration(milliseconds: 500)),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SpaceColors.sunflare.withValues(alpha: 0.3),
                    border: Border.all(color: SpaceColors.sunflare, width: 1.5),
                  ),
                  child: Icon(Icons.person_add_rounded, color: SpaceColors.sunflare, size: 14),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text('WAITING FOR FRIEND', style: TextStyle(
            color: SpaceColors.starWhite, fontSize: 12,
            fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          )),
          SizedBox(height: 12),
          if (match.matchId != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: SpaceColors.sunflare.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
                color: SpaceColors.hudBackground,
              ),
              child: Column(
                children: [
                  Text('SHARE THIS CODE', style: TextStyle(
                    color: SpaceColors.asteroidGrey, fontSize: 9,
                    fontFamily: AppFonts.body, letterSpacing: 2,
                  )),
                  SizedBox(height: 8),
                  SelectableText(
                    match.matchId!,
                    style: TextStyle(
                      color: SpaceColors.sunflare, fontSize: 11,
                      fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: match.matchId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Match ID copied!',
                            style: TextStyle(color: SpaceColors.starWhite, fontFamily: AppFonts.body, letterSpacing: 1.5)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: SpaceColors.sunflare.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(4),
                        color: SpaceColors.sunflare.withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: SpaceColors.sunflare, size: 14),
                          SizedBox(width: 6),
                          Text('COPY MATCH ID', style: TextStyle(
                            color: SpaceColors.sunflare, fontSize: 10,
                            fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 10),
          Text(
            'Your friend should paste this ID\nand tap JOIN on their device',
            style: TextStyle(
              color: SpaceColors.asteroidGrey, fontSize: 10, fontFamily: AppFonts.body,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),

      MatchStatus.found => Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(color: SpaceColors.difficultyBoy, width: 1.5),
              color:  SpaceColors.difficultyBoy.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.check_rounded, color: SpaceColors.difficultyBoy, size: 28),
          ),
          SizedBox(height: 20),
          Text(
            'VS  ${match.opponentName?.toUpperCase() ?? "UNKNOWN"}',
            style: TextStyle(
              color: SpaceColors.starWhite, fontSize: 18,
              fontFamily: AppFonts.body, fontWeight: FontWeight.bold,
              letterSpacing: 4.0,
            ),
          ),
          SizedBox(height: 6),
          Text('LOADING MATCH...', style: TextStyle(
            color: SpaceColors.cometGrey, fontSize: 10,
            fontFamily: AppFonts.body, letterSpacing: 3.0,
          )),
        ],
      ),

      _ => const SizedBox.shrink(),
    };
  }
}

class _PulsingRing extends StatefulWidget {
  final Color    color;
  final Duration delay;
  const _PulsingRing({required this.color, required this.delay});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => Container(
      width:  80 * _anim.value,
      height: 80 * _anim.value,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        border: Border.all(
          color: widget.color.withValues(alpha: (1 - _anim.value) * 0.6),
          width: 1.5,
        ),
      ),
    ),
  );
}

class _ActionButton extends ConsumerWidget {
  final MatchState match;
  const _ActionButton({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearching = match.status == MatchStatus.searching;
    final color       = isSearching ? SpaceColors.neonRed : SpaceColors.neonBlue;
    final label       = isSearching ? 'CANCEL' : 'FIND MATCH';
    final icon        = isSearching ? Icons.cancel_rounded : Icons.radar_rounded;
    final onTap       = isSearching
        ? () => ref.read(multiplayerProvider.notifier).cancelMatchmaking()
        : () => ref.read(multiplayerProvider.notifier).startMatchmaking();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
          borderRadius: BorderRadius.circular(4),
          color: color.withValues(alpha: 0.12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 10),
            Text(label, style: TextStyle(
              color:         color,
              fontSize:      13,
              fontFamily:    AppFonts.body,
              fontWeight:    FontWeight.bold,
              letterSpacing: 4.0,
              shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8)],
            )),
          ],
        ),
      ),
    );
  }
}