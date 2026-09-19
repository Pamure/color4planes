// lib/overlays/multiplayer_result_overlay.dart
//
// CHANGES vs previous version:
//  - Removed in-room rematch sync (rematchReady op codes, handshake timers).
//  - "Play Again" now goes to the multiplayer lobby for new matchmaking.
//    Both players land in the lobby at roughly the same time and often
//    re-match each other — but it's simple and 100% reliable.
//  - Auto-countdown label changed from "REMATCHING IN X…" to "PLAY AGAIN IN X…".
//  - onPlayAgain callback replaces onRematch.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/overlays/game_over_overlay.dart' show CornerBracket;

class MultiplayerResultOverlay extends StatefulWidget {
  final bool         iWon;
  final bool         opponentDisconnected;
  final VoidCallback onPlayAgain; // → leave match + navigate to lobby
  final VoidCallback onMenu;      // → leave match + navigate to home

  const MultiplayerResultOverlay({
    super.key,
    required this.iWon,
    required this.onPlayAgain,
    required this.onMenu,
    this.opponentDisconnected = false,
  });

  @override
  State<MultiplayerResultOverlay> createState() =>
      _MultiplayerResultOverlayState();
}

class _MultiplayerResultOverlayState extends State<MultiplayerResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  Timer? _autoTimer;
  int    _countdown = 5;

  @override
  void initState() {
    super.initState();

    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    // Auto-play-again after 5 seconds — only when opponent is still connected.
    if (!widget.opponentDisconnected) {
      _autoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() { _countdown--; });
        if (_countdown <= 0) {
          t.cancel();
          widget.onPlayAgain();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, mainColor, subtext) = widget.opponentDisconnected
        ? ('OPPONENT LEFT',   SpaceColors.cometGrey,  'Your opponent disconnected')
        : widget.iWon
            ? ('YOU WON',     SpaceColors.sunflare,   'Enemy forces eliminated')
            : ('YOU LOST',    SpaceColors.neonRed,    'Better luck next time');

    final icon = widget.opponentDisconnected
        ? Icons.wifi_off_rounded
        : widget.iWon
            ? Icons.military_tech_rounded
            : Icons.close_rounded;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          color: const Color(0xDD020616),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(UIDimensions.cardMargin),
                child: CornerBracket(
                  child: Container(
                    padding: const EdgeInsets.all(UIDimensions.cardPadding),
                    decoration: BoxDecoration(
                      color:        const Color(0xCC04091E),
                      borderRadius: BorderRadius.circular(UIDimensions.cardRadius),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // ── Icon ───────────────────────────────────────────
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape:  BoxShape.circle,
                            border: Border.all(
                              color: mainColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            color: mainColor.withValues(alpha: 0.08),
                          ),
                          child: Icon(
                            icon,
                            color: mainColor,
                            size:  30,
                            shadows: [
                              Shadow(
                                color:      mainColor.withValues(alpha: 0.8),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Title ──────────────────────────────────────────
                        Text(
                          title,
                          style: TextStyle(
                            color:         mainColor,
                            fontSize:      28,
                            fontFamily:    AppFonts.body,
                            fontWeight:    FontWeight.bold,
                            letterSpacing: 8.0,
                            shadows: [
                              Shadow(
                                color:      mainColor.withValues(alpha: 0.7),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtext.toUpperCase(),
                          style: TextStyle(
                            color:         SpaceColors.asteroidGrey,
                            fontSize:      10,
                            fontFamily:    AppFonts.body,
                            letterSpacing: 2.5,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Auto play-again countdown (normal end only) ────
                        if (!widget.opponentDisconnected) ...[
                          Text(
                            'PLAY AGAIN IN $_countdown...',
                            style: TextStyle(
                              color:         SpaceColors.neonBlue,
                              fontSize:      12,
                              fontFamily:    AppFonts.body,
                              fontWeight:    FontWeight.bold,
                              letterSpacing: 3.0,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Buttons ────────────────────────────────────────
                        if (widget.opponentDisconnected)
                          // Disconnect: HOME only
                          SizedBox(
                            width: double.infinity,
                            child: _ResultButton(
                              label: 'BACK TO MENU',
                              icon:  Icons.home_outlined,
                              color: SpaceColors.neonBlue,
                              onTap: widget.onMenu,
                            ),
                          )
                        else
                          // Normal end: HOME cancels auto-play-again
                          Row(
                            children: [
                              Expanded(
                                child: _ResultButton(
                                  label:   'HOME',
                                  icon:    Icons.home_outlined,
                                  color:   SpaceColors.cometGrey,
                                  outline: true,
                                  onTap: () {
                                    _autoTimer?.cancel();
                                    widget.onMenu();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _ResultButton(
                                  label: 'PLAY AGAIN',
                                  icon:  Icons.replay_rounded,
                                  color: SpaceColors.neonBlue,
                                  onTap: () {
                                    _autoTimer?.cancel();
                                    widget.onPlayAgain();
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
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

class _ResultButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         outline;
  final VoidCallback onTap;

  const _ResultButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: outline ? 0.3 : 0.55),
        ),
        color: outline ? Colors.transparent : color.withValues(alpha: 0.10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color:         color,
              fontSize:      12,
              fontFamily:    AppFonts.body,
              fontWeight:    FontWeight.bold,
              letterSpacing: 3.0,
              shadows: outline
                  ? null
                  : [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8)],
            ),
          ),
        ],
      ),
    ),
  );
}