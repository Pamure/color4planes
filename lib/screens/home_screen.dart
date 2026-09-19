// lib/screens/home_screen.dart
//
// REDESIGN: Cockpit-panel layout with Edit Name functionality.
// FIX: Added SingleChildScrollView and FittedBox to prevent laptop layout overflows.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/core/responsive.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/widgets/starfield_background.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user    = ref.watch(currentUserProvider);
    final auth    = ref.watch(authProvider);
    final padding = Responsive.screenPadding(context);

    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      // ── Logo ────────────────────────────────────────────────
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _GlowText(
                              'COLOR',
                              color:    SpaceColors.neonBlue,
                              size:     56,
                              spacing:  12,
                            ),
                            _GlowText(
                              '4PLANES',
                              color:    SpaceColors.neonRed,
                              size:     56,
                              spacing:  12,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '"what if 2cars was actually difficult"',
                          style: TextStyle(
                            color:         Colors.white70,
                            fontSize:      15,
                            fontFamily:    AppFonts.body,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ),

                      // ── Divider ──────────────────────────────────────────────
                      SizedBox(height: 36),
                      _NeonDivider(),
                      SizedBox(height: 28),

                      // ── Player card ────────────────────────────────────────
                      if (user != null) ...[
                        _StatPanel(
                          name:      user.displayName,
                          highScore: user.highScore,
                        ),
                        SizedBox(height: 32),
                      ],

                      // ── Buttons ──────────────────────────────────────────────
                      _NeonButton(
                        label:    'PLAY',
                        icon:     Icons.play_arrow_rounded,
                        color:    SpaceColors.neonBlue,
                        onTap:    () => context.push(RoutePaths.game),
                      ),
                      SizedBox(height: 12),
                      _NeonButton(
                        label:    'MULTIPLAYER',
                        icon:     Icons.people_rounded,
                        color:    SpaceColors.neonRed,
                        onTap:    () => context.push(RoutePaths.multiplayer),
                      ),
                      SizedBox(height: 12),
                      _OutlineButton(
                        label:    'SETTINGS',
                        icon:     Icons.settings_outlined,
                        onTap:    () => context.push(RoutePaths.settings),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _OutlineButton(
                              label: 'BOARD',
                              icon:  Icons.emoji_events_outlined,
                              onTap: () => context.push(RoutePaths.leaderboard),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _OutlineButton(
                              label: 'PROFILE',
                              icon:  Icons.person_outline_rounded,
                              onTap: () => context.push(RoutePaths.profile),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _OutlineButton(
                              label: 'FRIENDS',
                              icon:  Icons.people_outline_rounded,
                              onTap: () => context.push(RoutePaths.friends),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 40),

                      // ── Status badge ─────────────────────────────────────────
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: auth is AuthAuthenticated
                                    ? SpaceColors.difficultyBoy
                                    : SpaceColors.asteroidGrey,
                                boxShadow: auth is AuthAuthenticated
                                    ? [BoxShadow(
                                        color:      SpaceColors.difficultyBoy.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                      )]
                                    : null,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              auth is AuthAuthenticated ? 'ONLINE' : 'GUEST MODE',
                              style: TextStyle(
                                color:         SpaceColors.asteroidGrey,
                                fontSize:      10,
                                fontFamily:    AppFonts.body,
                                letterSpacing: 3.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Auth error (dev only) ─────────────────────────────────
                      if (auth is AuthGuest && AuthNotifier.lastError != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: SpaceColors.neonRed.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(4),
                            color: SpaceColors.neonRed.withValues(alpha: 0.08),
                          ),
                          child: Text(
                            AuthNotifier.lastError!,
                            style: TextStyle(
                              color:    SpaceColors.redGlow,
                              fontSize: 9,
                              fontFamily: AppFonts.body,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _GlowText extends StatelessWidget {
  final String text;
  final Color  color;
  final double size;
  final double spacing;
  const _GlowText(this.text, {required this.color, required this.size, required this.spacing});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color:         color,
      fontSize:      size,
      fontFamily:    AppFonts.title,
      fontWeight:    FontWeight.w900,
      letterSpacing: spacing,
      shadows: [
        Shadow(color: color.withValues(alpha: 0.9), blurRadius: 20),
        Shadow(color: color.withValues(alpha: 0.4), blurRadius: 40),
      ],
    ),
  );
}

class _NeonDivider extends StatelessWidget {
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
      Container(
        width: 6, height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: SpaceColors.neonBlue,
          shape: BoxShape.circle,
        ),
      ),
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [SpaceColors.neonRed, Colors.transparent],
            ),
          ),
        ),
      ),
    ],
  );
}

class _StatPanel extends StatelessWidget {
  final String name;
  final int    highScore;
  const _StatPanel({required this.name, required this.highScore});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: SpaceColors.dividerLine, width: 1),
      borderRadius: BorderRadius.circular(4),
      color:  SpaceColors.hudBackground,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // ── LEFT: Name + Edit Button ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PILOT',
                style: TextStyle(
                  color:         SpaceColors.asteroidGrey,
                  fontSize:      9,
                  fontFamily:    AppFonts.body,
                  letterSpacing: 3.0,
                ),
              ),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:         SpaceColors.starWhite,
                        fontSize:      16,
                        fontFamily:    AppFonts.body,
                        fontWeight:    FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  // The Edit Button
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.nameSetup),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: SpaceColors.neonBlue.withValues(alpha: 0.5),
                          width: 1
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: SpaceColors.neonBlue.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 12,
                        color: SpaceColors.neonBlue
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),

        // ── RIGHT: Score ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'BEST SCORE',
              style: TextStyle(
                color:         SpaceColors.asteroidGrey,
                fontSize:      9,
                fontFamily:    AppFonts.body,
                letterSpacing: 3.0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              highScore.toString().padLeft(6, '0'),
              style: TextStyle(
                color:         SpaceColors.sunflare,
                fontSize:      22,
                fontFamily:    AppFonts.body,
                fontWeight:    FontWeight.bold,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(color: SpaceColors.sunflare, blurRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NeonButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final VoidCallback onTap;
  const _NeonButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
          borderRadius: BorderRadius.circular(4),
          color:  color.withValues(alpha: 0.12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color:         color,
                  fontSize:      13,
                  fontFamily:    AppFonts.body,
                  fontWeight:    FontWeight.bold,
                  letterSpacing: 4.0,
                  shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 10)],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: SpaceColors.asteroidGrey.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: SpaceColors.cometGrey, size: 18),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color:         SpaceColors.cometGrey,
                  fontSize:      13,
                  fontFamily:    AppFonts.body,
                  fontWeight:    FontWeight.bold,
                  letterSpacing: 4.0,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
