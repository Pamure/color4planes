// lib/screens/splash_screen.dart
//
// Retro "system boot" splash — the game boots like a space-mission computer.
// Animates: logo fade-in → blue/red split lines close to center → navigate.
// Same starfield background as every other screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/widgets/starfield_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _fadeCtrl;
  late final AnimationController _lineCtrl;
  late final Animation<double>   _fade;
  late final Animation<double>   _lineSlide;
  late final Animation<double>   _logoScale;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _lineCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _lineSlide = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOutCubic);
    _logoScale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack));

    // Stagger: starfield fades in, then lines slide, then logo
    _fadeCtrl.forward().then((_) => _lineCtrl.forward());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  void _tryNavigate(AuthState authState) {
    if (_navigated) return;
    _navigated = true;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final hasName = authState.when(
        loading: () => true,
        guest:   (u) => u.displayName != 'notallowedname',
        authenticated: (u) => u.displayName != 'notallowedname',
      );
      if (hasName) {
        context.go(RoutePaths.home);
      } else {
        context.go(RoutePaths.nameSetup);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is! AuthLoading && _lineCtrl.isCompleted) _tryNavigate(next);
      if (next is! AuthLoading) {
        // Wait for line animation then navigate
        _lineCtrl.addStatusListener((s) {
          if (s == AnimationStatus.completed) _tryNavigate(next);
        });
      }
    });

    return Scaffold(
      body: StarfieldBackground(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeCtrl, _lineCtrl]),
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo ────────────────────────────────────────────────
                    ScaleTransition(
                      scale: _logoScale,
                      child: Column(
                        children: [
                          _SplashTitle('COLOR', SpaceColors.neonBlue),
                          SizedBox(height: 4),
                          _SplashTitle('4PLANES', SpaceColors.neonRed),
                        ],
                      ),
                    ),

                    SizedBox(height: 48),

                    // ── Animated scan-line bar ───────────────────────────────
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          // Blue line from left
                          Row(children: [
                            Container(
                              height: 2,
                              width:  200 * _lineSlide.value,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [SpaceColors.neonBlue, Colors.transparent],
                                ),
                              ),
                            ),
                          ]),
                          SizedBox(height: 8),
                          // Red line from right
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 2,
                                width:  200 * _lineSlide.value,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, SpaceColors.neonRed],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ── Boot text ────────────────────────────────────────────
                    Opacity(
                      opacity: _lineSlide.value,
                      child: Text(
                        'INITIALIZING SYSTEMS...',
                        style: TextStyle(
                          color:         SpaceColors.asteroidGrey,
                          fontSize:      10,
                          fontFamily:    AppFonts.body,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashTitle extends StatelessWidget {
  final String text;
  final Color  color;
  const _SplashTitle(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color:         color,
      fontSize:      52,
      fontFamily:    AppFonts.title,
      fontWeight:    FontWeight.w900,
      letterSpacing: 12.0,
      shadows: [
        Shadow(color: color.withValues(alpha: 0.8), blurRadius: 24),
        Shadow(color: color.withValues(alpha: 0.4), blurRadius: 48),
      ],
    ),
  );
}
