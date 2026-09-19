// lib/components/bullet_trail.dart
// Visual fading trail behind each bullet. Child of Bullet, removed with it.

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';

class BulletTrail extends Component with ParentIsA<PositionComponent> {
  final PlaneColor color;

  final List<Vector2> _positions = [];

  static final _colorMap = {
    PlaneColor.blue: const Color(0xFF7AB8F5), // SpaceColors.blueGlow
    PlaneColor.red:  const Color(0xFFF57A7A), // SpaceColors.redGlow
  };

  BulletTrail({required this.color});

  @override
  void update(double dt) {
    super.update(dt);
    _positions.add(parent.position.clone());
    if (_positions.length > ParticleConfig.trailLength) {
      _positions.removeAt(0); // Remove oldest — no new list created
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final baseColor = _colorMap[color] ?? Colors.white;
    for (int i = 0; i < _positions.length - 1; i++) {
      final opacity = (i / _positions.length) * ParticleConfig.trailOpacity;
      canvas.drawLine(
        _positions[i].toOffset(),
        _positions[i + 1].toOffset(),
        Paint()
          ..color       = baseColor.withValues(alpha: opacity)
          ..strokeWidth = ParticleConfig.trailWidth
          ..strokeCap   = StrokeCap.round,
      );
    }
  }
}
