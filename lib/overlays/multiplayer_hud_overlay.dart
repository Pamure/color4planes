// lib/overlays/multiplayer_hud_overlay.dart
//
// REDESIGN: Thin top/bottom bars.  No card boxes blocking the game.
// Opponent lives at very top edge, yours just above swap button.

import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/core/responsive.dart';

class MultiplayerHudOverlay extends StatelessWidget {
  final int          myLives;
  final int          opponentLives;
  final String       opponentName;
  final VoidCallback onSwapColors;
  final VoidCallback onQuit;

  const MultiplayerHudOverlay({
    super.key,
    required this.myLives,
    required this.opponentLives,
    required this.opponentName,
    required this.onSwapColors,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Top gradient (opponent zone) ─────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [
                  SpaceColors.neonRed.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Bottom gradient (player zone) ────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.bottomCenter,
                end:    Alignment.topCenter,
                colors: [
                  SpaceColors.neonBlue.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: Stack(
            children: [
              // ── Opponent lives (top) ────────────────────────────────────────
              Positioned(
                top: 6,
                left: Responsive.screenPadding(context),
                right: Responsive.screenPadding(context),
                child: _LivesStrip(
                  name:  opponentName.toUpperCase(),
                  lives: opponentLives,
                  max:   MultiplayerConfig.startingLives,
                  color: SpaceColors.neonRed,
                  flip:  true, // hearts at right, name at left
                ),
              ),

              // ── Quit button (top-left) ──────────────────────────────────────
              Positioned(
                top: 6,
                left: Responsive.screenPadding(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.exit_to_app_rounded, color: SpaceColors.starWhite, size: 24),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: onQuit,
                    tooltip: 'Leave Match',
                  ),
                ),
              ),

              // ── Your lives (bottom, above swap button) ──────────────────────
              Positioned(
                bottom: UIDimensions.swapButtonBottomPad + UIDimensions.swapButtonSize + 12,
                left:   Responsive.screenPadding(context),
                right:  Responsive.screenPadding(context),
                child: _LivesStrip(
                  name:  'YOU',
                  lives: myLives,
                  max:   MultiplayerConfig.startingLives,
                  color: SpaceColors.neonBlue,
                  flip:  false,
                ),
              ),

              // ── Swap button ─────────────────────────────────────────────────
              Positioned(
                bottom: UIDimensions.swapButtonBottomPad,
                left:   0,
                right:  0,
                child: Center(child: _MpSwapButton(onTap: onSwapColors)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LivesStrip extends StatelessWidget {
  final String name;
  final int    lives;
  final int    max;
  final Color  color;
  final bool   flip; // if true: name left, hearts right

  const _LivesStrip({
    required this.name,
    required this.lives,
    required this.max,
    required this.color,
    required this.flip,
  });

  @override
  Widget build(BuildContext context) {
    final hearts = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            filled ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            color:  filled ? color : SpaceColors.asteroidGrey.withValues(alpha: 0.5),
            size:   20,
            shadows: filled ? [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 8)] : null,
          ),
        );
      }),
    );

    final label = Text(
      name,
      style: TextStyle(
        color:         color.withValues(alpha: 0.8),
        fontSize:      10,
        fontFamily:    AppFonts.body,
        fontWeight:    FontWeight.bold,
        letterSpacing: 3.0,
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: flip
          ? [label, hearts]
          : [hearts, label],
    );
  }
}

class _MpSwapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MpSwapButton({required this.onTap});

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
          BoxShadow(color: SpaceColors.neonBlue.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(-3, 0)),
          BoxShadow(color: SpaceColors.neonRed.withValues(alpha: 0.35),  blurRadius: 14, offset: const Offset(3, 0)),
        ],
      ),
      child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: UIDimensions.swapButtonIconSize),
    ),
  );
}
