// lib/components/multiplayer_bullet.dart
//
// Multiplayer-specific player bullet.
//
// WHY this exists instead of reusing Bullet:
//   Bullet uses HasGameReference<FlameView> — when Flame resolves the generic
//   at runtime it casts the parent game to FlameView. In multiplayer the parent
//   is MultiplayerFlameGame, which is a DIFFERENT class. The cast throws a
//   TypeError the moment onLoad() calls game.loadSprite().
//
//   Keeping two separate classes is intentional: single-player and multiplayer
//   have different game-reference types and different collision targets.
//
// Collision outcomes (upward-traveling bullet in multiplayer):
//   • Hits OpponentPlane   → freeze ghost plane locally, tell opponent via network
//   • Hits OpponentBullet  → handled by OpponentBullet (it checks for this class)
//   • Exits top edge       → silent removal

import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:color4planes/components/opponent_plane.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/providers/multiplayer_provider.dart';
import 'package:color4planes/screens/multiplayer_game_screen.dart';

class MultiplayerPlayerBullet extends SpriteComponent
    with HasGameReference<MultiplayerFlameGame>, CollisionCallbacks {
  final PlaneColor color;

  static const double _speed  = GameConfig.bulletSpeed;
  static const double _width  = GameConfig.bulletWidth;
  static const double _height = GameConfig.bulletHeight;

  bool _hasCollided = false;

  MultiplayerPlayerBullet({
    required this.color,
    required Vector2 startPosition,
  }) : super(
          size:     Vector2(_width, _height),
          anchor:   Anchor.center,
          position: startPosition.clone(),
        );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    // game is now correctly typed as MultiplayerFlameGame — no cast error
    sprite = await game.loadSprite(
      color == PlaneColor.blue ? Assets.blueBullet : Assets.redBullet,
    );
    final hs = size * GameConfig.hitboxShrinkFactor;
    add(RectangleHitbox(size: hs, position: (size - hs) / 2));
  }

@override
  void update(double dt) {
    super.update(dt);
    if (_hasCollided) return;

    // FIX: Cap dt for network bullets
    final safeDt = dt.clamp(0.0, 0.05);

    position.y -= _speed * safeDt; // Use safeDt

    if (position.y < -_height) removeFromParent();
  }

  /// Called by OpponentBullet when two bullets of the same color collide.
  void markHit() {
    _hasCollided = true;
    removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (_hasCollided) return;

    // ── Hit: Opponent's ghost plane ───────────────────────────────────────
    if (other is OpponentPlane) {
      _hasCollided = true;
      removeFromParent();

      // Freeze the ghost plane visually on our screen
      other.freeze();

      // Tell opponent that one of their planes was frozen.
      // isLeft from OUR perspective: oppLeft is the opponent's right lane (mirrored).
      // We send from their perspective: oppLeft on our screen = their right plane.
      final isLeft = other == game.matchWorld?.oppRight;
      game.ref
          .read(multiplayerProvider.notifier)
          .sendPlaneHit(isLeft: isLeft);
    }
    // Note: OpponentBullet handles bullet-vs-bullet cancellation from its side.
    // We don't need to handle it here because OpponentBullet.onCollisionStart
    // already checks (other is MultiplayerPlayerBullet) and calls markHit().
  }
}
