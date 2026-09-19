// lib/components/opponent_bullet.dart
//
// Spawned when we receive a bulletFired event from the opponent.
// Travels DOWNWARD (positive Y direction) — the opposite of your own bullets.
//
// Collision outcomes:
//   • Hits PlayerPlane hitbox  → freeze that plane, call onPlayerPlaneHit()
//   • Hits your Bullet (same color) → both cancel, call onBulletCancel()
//   • Hits your Bullet (diff color) → pass through (no action)
//   • Exits bottom edge → you lose a life, call onOpponentBulletEscaped()
//
// NOTE: PlayerPlane MUST have a RectangleHitbox for collision to fire.
// See jet.dart for the fix.

import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:color4planes/components/multiplayer_bullet.dart';
import 'package:color4planes/components/jet.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/screens/multiplayer_game_screen.dart';

class OpponentBullet extends SpriteComponent
    with HasGameReference<MultiplayerFlameGame>, CollisionCallbacks {

  final PlaneColor color;

  static const double _speed  = GameConfig.bulletSpeed;
  static const double _width  = GameConfig.bulletWidth;
  static const double _height = GameConfig.bulletHeight;

  bool _hit = false;

  OpponentBullet({
    required this.color,
    required Vector2 startPosition,
  }) : super(
    size:     Vector2(_width, _height),
    anchor:   Anchor.center,
    position: startPosition,
    angle:    3.14159265, // Rotate 180° so bullet sprite points downward
  );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(
      color == PlaneColor.blue ? Assets.blueBullet : Assets.redBullet,
    );
    // Hitbox — non-solid so it overlaps player hitboxes and triggers callbacks
    final hs = size * GameConfig.hitboxShrinkFactor;
    add(RectangleHitbox(size: hs, position: (size - hs) / 2));
  }

@override
  void update(double dt) {
    super.update(dt);
    if (_hit) return;

    // FIX: Cap dt for incoming opponent bullets
    final safeDt = dt.clamp(0.0, 0.05);

    // Move DOWNWARD — positive Y
    position.y += _speed * safeDt; // Use safeDt

    if (position.y > game.size.y + _height) {
      if (!_hit) {
        _hit = true;
        game.matchWorld?.onOpponentBulletEscaped();
      }
      removeFromParent();
    }
  }  @override
  void onCollisionStart(
    Set<Vector2> points,
    PositionComponent other,
  ) {
    super.onCollisionStart(points, other);
    if (_hit) return;

    // ── Hit: Player's plane ──────────────────────────────────────────────────
    // Requires PlayerPlane to have a RectangleHitbox (fixed in jet.dart).
    if (other is PlayerPlane) {
      _hit = true;
      game.matchWorld?.onPlayerPlaneHit(other);
      removeFromParent();
      return;
    }

    // ── Hit: Player's bullet ─────────────────────────────────────────────────
    if (other is MultiplayerPlayerBullet) {
      if (color == other.color) {
        // SAME COLOR → both cancel and disappear
        _hit = true;
        other.markHit();
        game.matchWorld?.onBulletCancel(position.clone(), color);
        removeFromParent();
        return;
      }
      // DIFFERENT COLOR → pass through — do nothing
    }
  }
}
