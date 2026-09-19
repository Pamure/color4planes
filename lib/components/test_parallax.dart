// lib/components/test_parallax.dart
//
// SCRATCH FILE — kept for reference only. Not used in production.

import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

class ParallaxTest extends FlameGame {
  @override
  Future<void> onLoad() async {
    final parallax = await loadParallaxComponent([
      ParallaxImageData('test.png'),
    ]);
    
    // Test: access layer paint
    parallax.parallax!.layers[0].currentPaint.color = Colors.red;
  }
}
