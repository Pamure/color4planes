// lib/components/bullet.dart

import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:color4planes/components/alien_ship.dart';
//import 'package:color4planes/components/bullet_trail.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/providers/game_provider.dart';
import 'package:color4planes/screens/game_screen.dart';

class Bullet extends SpriteComponent
    with HasGameReference<FlameView>, CollisionCallbacks {
  final PlaneColor color;

  static const double _speed = GameConfig.bulletSpeed;
  static const double _width = GameConfig.bulletWidth;
  static const double _height = GameConfig.bulletHeight;

  bool _hasCollided = false;

  Bullet({required this.color, required Vector2 startPosition}) {
    size = Vector2(_width, _height);
    anchor = Anchor.center;
    position = startPosition.clone();
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(
      color == PlaneColor.blue ? Assets.blueBullet : Assets.redBullet,
    );
    // Hitbox is full-size for bullets — they're only 10px wide, no need to shrink.
    // NOTE: Do NOT guard with `if (!isMounted)` — isMounted is false during
    // onLoad() in Flame 1.35+, which would prevent the hitbox from ever being added.
    add(RectangleHitbox(size: size.clone()));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hasCollided) return;

    // FIX: Cap dt to 0.05s max (equivalent to 20fps minimum physics step)
    final safeDt = dt.clamp(0.0, 0.05);

    position.y -= _speed * safeDt; // Use safeDt instead of dt

    if (position.y < -_height) removeFromParent();
  }

  // Add inside Bullet class, after onCollisionStart:
  void markHit() {
    _hasCollided = true;
    removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_hasCollided) return;
    if (other is! AlienShip || other.isDestroyed) return;
    // 1. FIRST, check if the game is actually playing. If not, ignore the collision entirely.
    if (game.ref.read(gameSessionProvider).status != GameStatus.playing) return;

    _hasCollided = true;

    if (color == other.shipColor) {
      other.destroy();
      removeFromParent();
      game.mainView?.onShipDestroyedAt(
        other.position,
        other.shipColor,
        GameConfig.basePointsPerKill,
      );
    } else {
      game.mainView?.onGameOver();
    }
  }
}
