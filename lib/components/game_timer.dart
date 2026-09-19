// lib/components/game_timer.dart
//
// Renders the survival timer on the Flame canvas (not in Flutter HUD).
// Reads time via a function closure — no Riverpod, no Flutter rebuilds.
// Updates text only when the second changes: 1 String/sec not 60.

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameTimerDisplay extends TextComponent with HasGameReference {
  final double Function() getTime;
  int _lastSecond = -1;

  GameTimerDisplay({required this.getTime})
      : super(
          text: '00:00',
          textRenderer: TextPaint(
            style: const TextStyle(
              color:      Color(0xFFB0B0C8),
              fontSize:   14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        );

  @override
  void onLoad() {
    super.onLoad();
    anchor   = Anchor.topRight;
    position = Vector2(game.size.x - 16, 60);
  }
@override
void onGameResize(Vector2 size) {
  super.onGameResize(size);
  position = Vector2(size.x - 16, 60); // Update on every resize
}
  @override
  void update(double dt) {
    super.update(dt);
    final elapsed       = getTime();
    final currentSecond = elapsed.floor();
    if (currentSecond != _lastSecond) {
      _lastSecond = currentSecond;
      final m = (elapsed / 60).floor();
      final s = (elapsed % 60).floor();
      text = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }
}
