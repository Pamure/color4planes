// lib/components/explosion.dart
// Particle burst on ship destruction. No changes from v2.

import 'dart:async' as async;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';

class _Particle extends PositionComponent {
  final Vector2 velocity;
  final Color color;
  final double lifetime;
  double _age = 0;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _Particle({
    required Vector2 startPos,
    required this.velocity,
    required this.color,
    required this.lifetime,
  }) {
    position = startPos.clone();
    size = Vector2(ParticleConfig.size, ParticleConfig.size);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.add(velocity * dt);
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final alpha = (1.0 - (_age / lifetime)).clamp(0.0, 1.0);

    _paint.color = color.withValues(alpha: alpha);

    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, _paint);
  }
}

class ExplosionEffect extends Component {
  final Vector2 position;
  final PlaneColor color;
  async.Timer? _cleanupTimer;

  static final _colorMap = {
    PlaneColor.blue: const Color(0xFF5CB8FF),
    PlaneColor.red: const Color(0xFFFF6B6B),
  };

  ExplosionEffect({required this.position, required this.color});

  @override
  async.FutureOr<void> onLoad() async {
    await super.onLoad();
    final rng = Random();
    final baseColor = _colorMap[color] ?? Colors.white;

    for (int i = 0; i < ParticleConfig.count; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed =
          ParticleConfig.speedMin +
          rng.nextDouble() *
              (ParticleConfig.speedMax - ParticleConfig.speedMin);
      final lifetime =
          ParticleConfig.lifetimeMin +
          rng.nextDouble() *
              (ParticleConfig.lifetimeMax - ParticleConfig.lifetimeMin);
      add(
        _Particle(
          startPos: position,
          velocity: Vector2(cos(angle) * speed, sin(angle) * speed),
          color: baseColor,
          lifetime: lifetime,
        ),
      );
    }
    //probably the main reason behind the lag glitch
    //Future.delayed(Duration(milliseconds: ParticleConfig.cleanupMs), removeFromParent);
    _cleanupTimer = async.Timer(
      Duration(milliseconds: ParticleConfig.cleanupMs),
      () => removeFromParent(),
    );
  }

  @override
  void onRemove() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    super.onRemove();
  }
}
