// lib/components/alien_ship.dart

import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:color4planes/components/jet.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/providers/game_provider.dart';
import 'package:color4planes/screens/game_screen.dart';

class AlienShip extends SpriteComponent
    with HasGameReference<FlameView>, CollisionCallbacks {
  final PlaneColor shipColor;
  final int lane;
  final double speed;

  static const double shipSize = GameConfig.alienSize;
  bool isDestroyed = false;

  AlienShip({
    required this.shipColor,
    required this.lane,
    required Vector2 startPosition,
    this.speed = 150.0,
  }) {
    size = Vector2(shipSize, shipSize);
    anchor = Anchor.center;
    position = startPosition.clone();
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite(
      shipColor == PlaneColor.blue ? Assets.blueAlien : Assets.redAlien,
    );
    // NOTE: Do NOT guard with `if (!isMounted)` — isMounted is false during
    // onLoad() in Flame 1.35+, which would prevent the hitbox from ever being added.
    // Use 90% size hitbox — tight but forgiving for touch-based gameplay.
    final hitboxSize = size * 0.9;
    add(RectangleHitbox(size: hitboxSize, position: (size - hitboxSize) / 2));
  }
@override
  void update(double dt) {
    super.update(dt);
    if (isDestroyed) return;

    final safeDt = dt.clamp(0.0, 0.05); // You added this in Step 3!
    position.y += speed * safeDt;

    if (position.y + size.y / 2 >= game.size.y) {
      if (game.ref.read(gameSessionProvider).status == GameStatus.playing) {
        game.mainView?.onGameOver();
      }
      // FIX: Tell the bouncer we are leaving!
      game.mainView?.spawnManager.onShipDestroyed();
      isDestroyed = true; // Prevent double-counting
      removeFromParent();
    }
  }

  // @override
  // void update(double dt) {
  //   super.update(dt);
  //   if (isDestroyed) return;

  //   // FIX: Same dt cap. Aliens shouldn't teleport at low FPS either.
  //   final safeDt = dt.clamp(0.0, 0.05);

  //   position.y += speed * safeDt; // Use safeDt instead of dt

  //   if (position.y + size.y / 2 >= game.size.y) {
  //     if (game.ref.read(gameSessionProvider).status == GameStatus.playing) {
  //       game.mainView?.onGameOver();
  //     }
  //     removeFromParent();
  //   }
  // }

@override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (isDestroyed || other is! PlayerPlane) return;
    if (game.ref.read(gameSessionProvider).status != GameStatus.playing) return;

    // FIX: Tell the bouncer we are leaving!
    game.mainView?.spawnManager.onShipDestroyed();
    isDestroyed = true;

    game.mainView?.onGameOver();
  }


  void destroy() {
    if (isDestroyed) return;
    isDestroyed = true;
    removeFromParent();
  }
}
