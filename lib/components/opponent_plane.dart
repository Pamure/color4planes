// lib/components/opponent_plane.dart
//
// The ghost planes at the top of the screen. Purely visual — they move
// and animate only in response to incoming network events.

import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';
import 'package:color4planes/screens/multiplayer_game_screen.dart';

/// The opponent's planes — rendered at the TOP of the screen, rotated 180°.
///
/// Position and color are updated by incoming network events from
/// MultiplayerMatchWorld._onMatchData(). This component is purely visual.
class OpponentPlane extends SpriteComponent
    with HasGameReference<MultiplayerFlameGame> {

  PlaneColor planeColor;
  int        currentLane;
  bool       isFrozen     = false;
  double     _freezeTimer = 0.0;

  OpponentPlane({
    required this.planeColor,
    required this.currentLane,
    required Vector2 planeSize,
  }) : super(
    size:   planeSize,
    anchor: Anchor.center,
    angle:  3.14159265, // π = 180° — faces downward toward player
  );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();
    // Hitbox so player bullets can collide with opponent planes
    final hs = size * GameConfig.hitboxShrinkFactor;
    add(RectangleHitbox(
      size:     hs,
      position: (size - hs) / 2,
      isSolid:  true,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isFrozen) {
      _freezeTimer -= dt;
      if (_freezeTimer <= 0.0) {
        isFrozen = false;
        paint.color = paint.color.withOpacity(1.0);
      }
    }
  }

  /// Apply lane freeze (called when a player bullet hits this plane).
  void freeze() {
    isFrozen     = true;
    _freezeTimer = MultiplayerConfig.freezeDuration;
    paint.color  = paint.color.withOpacity(0.45);
  }

  /// Move to a new lane (called when opponent sends laneSwitched event).
  void setLane(int lane) {
    currentLane = lane;
  }

  /// Swap color (called when opponent sends colorSwapped event).
  Future<void> swapColor() async {
    planeColor = planeColor == PlaneColor.blue ? PlaneColor.red : PlaneColor.blue;
    await _loadSprite();
  }

  Future<void> _loadSprite() async {
    sprite = await game.loadSprite(
      planeColor == PlaneColor.blue ? Assets.bluePlane : Assets.redPlane,
    );
  }
}
