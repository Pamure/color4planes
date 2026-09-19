// lib/widgets/starfield_background.dart
//
// Multi-layer scrolling parallax with drifting meteor debris.
// Used on every Flutter screen outside of the Flame game canvas.
//
// Layers (back to front):
//   0. spaceParralax.png — deep-space starfield, slowest scroll (40s)
//   1. layer1.png — mid-depth star clusters (28s)
//   2. layer2.png — near-field stars (18s)
//   3. Floating meteor/asteroid sprites — random drift, subtle rotation
//   4. Top/bottom gradient vignette for text readability
//   5. Child content

import 'dart:math';
import 'package:flutter/material.dart';

// ── Meteor debris layer ──────────────────────────────────────────────────────

const _meteorAssets = [
  'assets/images/meteorBrown_big1.png',
  'assets/images/meteorBrown_big2.png',
  'assets/images/meteorBrown_med1.png',
  'assets/images/meteorGrey_big1.png',
  'assets/images/meteorGrey_big2.png',
  'assets/images/meteorGrey_med1.png',
  'assets/images/meteorGrey_small1.png',
  'assets/images/meteorBrown_small1.png',
];

class _Meteor {
  double x;       // 0..1 fraction across screen width
  double y;       // current y position (pixels)
  double speed;   // px/s downward
  double size;    // rendered size
  double rotation;
  double rotSpeed;
  String asset;
  double opacity;

  _Meteor({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotSpeed,
    required this.asset,
    required this.opacity,
  });
}

// ── Main widget ──────────────────────────────────────────────────────────────

class StarfieldBackground extends StatefulWidget {
  final Widget child;
  const StarfieldBackground({super.key, required this.child});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  final List<_Meteor> _meteors = [];
  double _lastT = 0;
  bool _meteorsInitialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // 120s so the three parallax layers can divide evenly
      duration: const Duration(seconds: 120),
    )..repeat();
    _ctrl.addListener(_updateMeteors);
  }

  void _initMeteors(double h, double w) {
    _meteors.clear();
    // 6-10 meteors depending on screen area
    final count = 6 + _rng.nextInt(5);
    for (int i = 0; i < count; i++) {
      _meteors.add(_spawnMeteor(h, w, randomY: true));
    }
    _meteorsInitialized = true;
  }

  _Meteor _spawnMeteor(double h, double w, {bool randomY = false}) {
    final asset = _meteorAssets[_rng.nextInt(_meteorAssets.length)];
    final isBig = asset.contains('big');
    final isMed = asset.contains('med');
    final baseSize = isBig ? 28.0 : (isMed ? 18.0 : 12.0);
    final size = baseSize + _rng.nextDouble() * 10;
    return _Meteor(
      x: 0.05 + _rng.nextDouble() * 0.9,
      y: randomY ? _rng.nextDouble() * h : -size - _rng.nextDouble() * 80,
      speed: 8 + _rng.nextDouble() * 18, // slow drift 8-26 px/s
      size: size,
      rotation: _rng.nextDouble() * 2 * pi,
      rotSpeed: (_rng.nextDouble() - 0.5) * 0.6, // rad/s
      asset: asset,
      opacity: 0.15 + _rng.nextDouble() * 0.25, // very subtle: 0.15-0.40
    );
  }

  void _updateMeteors() {
    if (!_meteorsInitialized) return;
    final t = _ctrl.value * 120; // seconds
    final dt = t - _lastT;
    if (dt <= 0 || dt > 1) {
      _lastT = t;
      return;
    }
    _lastT = t;

    final ctx = context;
    if (!ctx.mounted) return;
    final size = MediaQuery.sizeOf(ctx);

    for (int i = 0; i < _meteors.length; i++) {
      final m = _meteors[i];
      m.y += m.speed * dt;
      m.rotation += m.rotSpeed * dt;
      // Respawn off-top when past bottom
      if (m.y > size.height + m.size) {
        _meteors[i] = _spawnMeteor(size.height, size.width);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateMeteors);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight > 0 ? constraints.maxHeight : 800.0;
        final w = constraints.maxWidth > 0 ? constraints.maxWidth : 400.0;

        if (!_meteorsInitialized) {
          _initMeteors(h, w);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 0: Deep space (slowest) ─────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                // 40s cycle = ctrl.value * 120 / 40 = ctrl.value * 3
                final offset = (_ctrl.value * 3 % 1.0) * h;
                return _ScrollingLayer(
                  assetPath: 'assets/images/spaceParralax.png',
                  offset: offset,
                  height: h,
                );
              },
            ),

            // ── Layer 1: Mid stars ────────────────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                // 28s cycle
                final offset = (_ctrl.value * 120 / 28 % 1.0) * h;
                return Opacity(
                  opacity: 0.6,
                  child: _ScrollingLayer(
                    assetPath: 'assets/images/layer1.png',
                    offset: offset,
                    height: h,
                  ),
                );
              },
            ),

            // ── Layer 2: Near stars ───────────────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                // 18s cycle
                final offset = (_ctrl.value * 120 / 18 % 1.0) * h;
                return Opacity(
                  opacity: 0.45,
                  child: _ScrollingLayer(
                    assetPath: 'assets/images/layer2.png',
                    offset: offset,
                    height: h,
                  ),
                );
              },
            ),

            // ── Floating meteors ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                return CustomPaint(
                  painter: _MeteorPainter(
                    meteors: _meteors,
                    screenWidth: w,
                    images: const {},  // we use widget children instead
                  ),
                  child: SizedBox.expand(
                    child: Stack(
                      children: _meteors.map((m) {
                        return Positioned(
                          left: m.x * w - m.size / 2,
                          top: m.y,
                          child: Transform.rotate(
                            angle: m.rotation,
                            child: Opacity(
                              opacity: m.opacity,
                              child: Image.asset(
                                m.asset,
                                width: m.size,
                                height: m.size,
                                fit: BoxFit.contain,
                                // Cache for performance
                                cacheWidth: (m.size * 2).toInt(),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),

            // ── Top/bottom vignette for text readability ─────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: h * 0.15,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xAA020616),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: h * 0.1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0x88020616),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Child content ────────────────────────────────────────────
            widget.child,
          ],
        );
      },
    );
  }
}

// ── Scrolling layer (two copies for seamless loop) ───────────────────────────

class _ScrollingLayer extends StatelessWidget {
  final String assetPath;
  final double offset;
  final double height;

  const _ScrollingLayer({
    required this.assetPath,
    required this.offset,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -offset,
          left: 0,
          right: 0,
          height: height,
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
        Positioned(
          top: height - offset,
          left: 0,
          right: 0,
          height: height,
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
      ],
    );
  }
}

// Placeholder painter — we use Image.asset widgets instead of painting
class _MeteorPainter extends CustomPainter {
  final List<_Meteor> meteors;
  final double screenWidth;
  final Map<String, dynamic> images;

  _MeteorPainter({
    required this.meteors,
    required this.screenWidth,
    required this.images,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Painting is handled by Image.asset widgets in the Stack above
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter old) => true;
}
