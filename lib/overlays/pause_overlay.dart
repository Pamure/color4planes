// lib/overlays/pause_overlay.dart
//
// REDESIGN: Minimal cockpit-style pause panel. Corner brackets + neon dividers.

import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/overlays/game_over_overlay.dart' show CornerBracket;

class PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onMainMenu;

  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onMainMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xBB020616),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(UIDimensions.cardMargin),
            child: CornerBracket(
              child: Container(
                padding: const EdgeInsets.all(UIDimensions.cardPadding),
                decoration: BoxDecoration(
                  color: const Color(0xCC04091E),
                  borderRadius: BorderRadius.circular(UIDimensions.cardRadius),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Title ─────────────────────────────────────────────────
                    Text(
                      '// PAUSED',
                      style: TextStyle(
                        color:         SpaceColors.asteroidGrey,
                        fontSize:      10,
                        fontFamily:    AppFonts.body,
                        letterSpacing: 4.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'GAME SUSPENDED',
                      style: TextStyle(
                        color:         SpaceColors.starWhite,
                        fontSize:      22,
                        fontFamily:    AppFonts.body,
                        fontWeight:    FontWeight.bold,
                        letterSpacing: 6.0,
                        shadows: [
                          Shadow(color: SpaceColors.neonBlue, blurRadius: 16),
                        ],
                      ),
                    ),

                    SizedBox(height: 28),

                    // ── Neon divider ─────────────────────────────────────────
                    _PauseDivider(),

                    SizedBox(height: 28),

                    // ── Resume ────────────────────────────────────────────────
                    _PauseButton(
                      label:   'RESUME',
                      icon:    Icons.play_arrow_rounded,
                      color:   SpaceColors.neonBlue,
                      onTap:   onResume,
                    ),
                    SizedBox(height: 12),

                    // ── Menu ──────────────────────────────────────────────────
                    _PauseButton(
                      label:   'MAIN MENU',
                      icon:    Icons.home_outlined,
                      color:   SpaceColors.cometGrey,
                      outline: true,
                      onTap:   onMainMenu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, SpaceColors.neonBlue],
            ),
          ),
        ),
      ),
      SizedBox(width: 8),
      Container(
        width: 4, height: 4,
        decoration: const BoxDecoration(
          color: SpaceColors.neonBlue,
          shape: BoxShape.circle,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [SpaceColors.neonBlue, Colors.transparent],
            ),
          ),
        ),
      ),
    ],
  );
}

class _PauseButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final bool      outline;
  final VoidCallback onTap;

  const _PauseButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: outline ? 0.3 : 0.55)),
          color: outline ? Colors.transparent : color.withValues(alpha: 0.10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:         color,
                fontSize:      13,
                fontFamily:    AppFonts.body,
                fontWeight:    FontWeight.bold,
                letterSpacing: 4.0,
                shadows: outline ? null : [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
