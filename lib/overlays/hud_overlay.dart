// lib/overlays/hud_overlay.dart
//
// REDESIGN: Ultra-minimal cockpit-style HUD.
//
// BEFORE: Opaque dark card covering ~70px of gameplay at top.
// AFTER:  Thin transparent bar with a soft top-edge gradient.
//         Numbers read cleanly over the starfield.  No wasted space.
//
// Layout (top-to-bottom, 48px total):
//   [SCORE  number]   [⏸]   [KILLS  number]
//
// Swap button: redesigned with neon split — visually striking, minimal footprint.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/core/responsive.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/providers/game_provider.dart';

class HUDOverlay extends ConsumerWidget {
  final VoidCallback onSwapColors;
  final VoidCallback onPause;

  const HUDOverlay({super.key, required this.onSwapColors, required this.onPause});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score          = ref.watch(gameSessionProvider.select((s) => s.score));
    final shipsDestroyed = ref.watch(gameSessionProvider.select((s) => s.shipsDestroyed));
    final highScore      = ref.watch(currentUserProvider.select((u) => u?.highScore ?? 0));
    final isMobile       = Responsive.isMobile(context);
    final size=Responsive.swapButtonSize(context);
    return Stack(fit: StackFit.expand,
      children: [
        // ── Top edge gradient — cockpit visor effect ─────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [
                  const Color(0xCC020616),
                  const Color(0x88020616),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── HUD row ──────────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.screenPadding(context),
              vertical:   6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score
                _HudStat(
                  label:     'SCORE',
                  value:     score.toString().padLeft(5, '0'),
                  sublabel:  'BEST ${highScore.toString().padLeft(5, '0')}',
                  color:     SpaceColors.sunflare,
                  align:     CrossAxisAlignment.start,
                ),

                const Spacer(),

                // Pause button
                GestureDetector(
                  onTap: onPause,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.pause_rounded,
                      color: SpaceColors.asteroidGrey,
                      size:  isMobile ? 22 : 20,
                    ),
                  ),
                ),

                const Spacer(),

                // Ships destroyed
                _HudStat(
                  label:    'KILLS',
                  value:    shipsDestroyed.toString().padLeft(3, '0'),
                  sublabel: '',
                  color:    SpaceColors.neonBlue,
                  align:    CrossAxisAlignment.end,
                ),
              ],
            ),
          ),
        ),

        // ── Swap button ───────────────────────────────────────────────────────
        Positioned(
          bottom: UIDimensions.swapButtonBottomPad,
          left:   0,
          right:  0,
          child: Center(child: _SwapButton(onTap: onSwapColors)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HudStat extends StatelessWidget {
  final String           label;
  final String           value;
  final String           sublabel;
  final Color            color;
  final CrossAxisAlignment align;

  const _HudStat({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
    required this.align,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color:         SpaceColors.asteroidGrey,
          fontSize:      8,
          fontFamily:    AppFonts.body,
          letterSpacing: 3.0,
        ),
      ),
      SizedBox(height: 1),
      Text(
        value,
        style: TextStyle(
          color:         color,
          fontSize:      22,
          fontFamily:    AppFonts.body,
          fontWeight:    FontWeight.bold,
          letterSpacing: 2.0,
          shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 10)],
        ),
      ),
      if (sublabel.isNotEmpty)
        Text(
          sublabel,
          style: TextStyle(
            color:         SpaceColors.asteroidGrey,
            fontSize:      8,
            fontFamily:    AppFonts.body,
            letterSpacing: 1.5,
          ),
        ),
    ],
  );
}

class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width:  UIDimensions.swapButtonSize,
      height: UIDimensions.swapButtonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [SpaceColors.neonBlue, SpaceColors.neonRed],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:      SpaceColors.neonBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(-3, 0),
          ),
          BoxShadow(
            color:      SpaceColors.neonRed.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: Icon(
        Icons.swap_horiz_rounded,
        color: Colors.white,
        size:  UIDimensions.swapButtonIconSize,
      ),
    ),
  );
}
