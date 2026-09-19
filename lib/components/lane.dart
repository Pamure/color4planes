// lib/components/lane.dart — Unchanged from v2

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:color4planes/core/constants.dart';

class Lane extends PositionComponent {
  final int laneIndex;

  Lane({required this.laneIndex, required double x, required double width, required double height}) {
    position = Vector2(x, 0);
    size     = Vector2(width, height);
  }

  void updateSize(double x, double width, double height) {
    position = Vector2(x, 0);
    size     = Vector2(width, height);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = SpaceColors.laneTint);
    if (laneIndex == 1) {
      canvas.drawLine(
        Offset(size.x, 0), Offset(size.x, size.y),
        Paint()..color = SpaceColors.dividerLine..strokeWidth = 2.0,
      );
    }
  }
}
