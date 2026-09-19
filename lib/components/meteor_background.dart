// lib/components/meteor_background.dart
//
// Native Flame SpriteComponent layer that exactly simulates the drifting
// meteors from the Flutter CustomPainter, but natively within WebGL/Canvas
// to eliminate dual-surface compositing lag.

import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

const _meteorAssets = [
  'meteorBrown_big1.png',
  'meteorBrown_big2.png',
  'meteorBrown_med1.png',
  'meteorGrey_big1.png',
  'meteorGrey_big2.png',
  'meteorGrey_med1.png',
  'meteorGrey_small1.png',
  'meteorBrown_small1.png',
];

class MeteorBackgroundComponent extends Component with HasGameReference<FlameGame> {
  final _rng = Random();

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    // Decide how many meteors based on screen size (roughly 6-10)
    final count = 6 + _rng.nextInt(5);
    for (int i = 0; i < count; i++) {
      add(_MeteorSprite(randomY: true));
    }
  }
}

class _MeteorSprite extends SpriteComponent with HasGameReference<FlameGame> {
  final _rng = Random();
  late double _speed;
  late double _rotSpeed;
  final bool randomY;

  _MeteorSprite({this.randomY = false});

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    
    final asset = _meteorAssets[_rng.nextInt(_meteorAssets.length)];
    final isBig = asset.contains('big');
    final isMed = asset.contains('med');
    final baseSize = isBig ? 28.0 : (isMed ? 18.0 : 12.0);
    final finalSize = baseSize + _rng.nextDouble() * 10;
    
    sprite = await game.loadSprite(asset);
    size = Vector2.all(finalSize);
    anchor = Anchor.center;
    
    // speed between 8 and 26 px/s
    _speed = 8 + _rng.nextDouble() * 18;
    // rotation in rad/s
    _rotSpeed = (_rng.nextDouble() - 0.5) * 0.6;
    
    // Opacity
    paint.isAntiAlias = false; 
    setOpacity(0.15 + _rng.nextDouble() * 0.25);
    
    _resetPosition();
  }

  void _resetPosition() {
    final w = game.size.x > 0 ? game.size.x : 400.0;
    final h = game.size.y > 0 ? game.size.y : 800.0;
    
    // x = 0.05 to 0.95 of screen
    final startX = (0.05 + _rng.nextDouble() * 0.9) * w;
    // y = random or above top
    final startY = randomY ? _rng.nextDouble() * h : -size.y - _rng.nextDouble() * 80;
    
    position = Vector2(startX, startY);
    angle = _rng.nextDouble() * 2 * pi;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Safe dt to prevent massive jumps during loading stutters
    final safeDt = dt.clamp(0.0, 0.05);
    
    position.y += _speed * safeDt;
    angle += _rotSpeed * safeDt;
    
    if (position.y > game.size.y + size.y) {
      _resetPosition();
      // Ensure it starts from top when respawning
      position.y = -size.y - _rng.nextDouble() * 80;
    }
  }
}
