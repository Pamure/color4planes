// lib/components/jet.dart
//
// FIXES:
//
// FIX 1 — HasGameReference<FlameGame> instead of HasGameReference<MultiplayerFlameGame>.
//   PlayerPlane is used in BOTH game_screen.dart (FlameView) AND
//   multiplayer_game_screen.dart (MultiplayerFlameGame).
//   The old code had <MultiplayerFlameGame> which caused a runtime cast error
//   in single-player: FlameView is not a MultiplayerFlameGame.
//   Using the base class <FlameGame> works in both contexts because loadSprite()
//   is defined on FlameGame.
//
// FIX 2 — Removed circular import of multiplayer_game_screen.dart.
//   That import was only there to supply the type parameter. No longer needed.
//
// FIX 3 — Added resetToDefault() for single-player restart.
//   Restores the plane to its original color and clears all cooldown/freeze state.
//
// FIX 4 — bulletCooldown referenced via GameConfig.bulletCooldown (alias added
//   in constants.dart) instead of non-existent field.

import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/player_state.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PlayerPlane
// Controls: two planes the LOCAL player controls (bottom of screen).
// Used in both solo (FlameView) and multiplayer (MultiplayerFlameGame).
// ══════════════════════════════════════════════════════════════════════════════

class PlayerPlane extends SpriteComponent
    with HasGameReference<FlameGame> { // FIX 1: FlameGame, not MultiplayerFlameGame

  PlaneColor planeColor;
  int        currentLane;

  // Initial (default) color — used by resetToDefault() to restore after swaps.
  final PlaneColor _defaultColor;

  // ── Multiplayer freeze state ───────────────────────────────────────────────
  bool   isFrozen     = false;
  double _freezeTimer = 0.0;

  // ── Shooting cooldown ──────────────────────────────────────────────────────
  double _shootCooldown = 0.0;
  // FIX 4: GameConfig.bulletCooldown now exists as an alias for shootCooldown.
  static const double _minShootInterval = GameConfig.bulletCooldown;

  PlayerPlane({
    required this.planeColor,
    required this.currentLane,
    required Vector2 planeSize,
  })  : _defaultColor = planeColor,
        super(
          size:   planeSize,
          anchor: Anchor.center,
        );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    await _loadSprite();

    // Hitbox so OpponentBullet.onCollisionStart fires on overlap.
    // isSolid: true → stops other solid hitboxes (e.g., OpponentPlane hitbox).
    // NOTE: Do NOT guard with `if (!isMounted)` — isMounted is false during
    // onLoad() in Flame 1.35+, which would prevent the hitbox from ever being added.
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

    if (_shootCooldown > 0) _shootCooldown -= dt;

    if (isFrozen) {
      _freezeTimer -= dt;
      if (_freezeTimer <= 0.0) {
        isFrozen = false;
        paint.color = paint.color.withValues(alpha: 1.0);
      }
    }
  }

  // ── Shooting ────────────────────────────────────────────────────────────────
  /// Returns true if a bullet can be fired (respects cooldown + frozen state).
  bool shoot() {
    if (isFrozen) return false;
    if (_shootCooldown > 0) return false;
    _shootCooldown = _minShootInterval;
    return true;
  }

  // ── Lane switching ──────────────────────────────────────────────────────────
  void switchLane(int newLane) => currentLane = newLane;

  // ── Multiplayer freeze ─────────────────────────────────────────────────────
  /// Called when an OpponentBullet's hitbox overlaps this plane.
  /// Visual feedback: dims the plane; it cannot shoot while frozen.
  void freeze() {
    isFrozen     = true;
    _freezeTimer = MultiplayerConfig.freezeDuration;
    paint.color  = paint.color.withValues(alpha: 0.4);
  }

  // ── Color swap ─────────────────────────────────────────────────────────────
  Future<void> swapColor() async {
    planeColor = planeColor == PlaneColor.blue ? PlaneColor.red : PlaneColor.blue;
    await _loadSprite();
  }

  // ── FIX 3: Reset for single-player restart ─────────────────────────────────
  /// Restores the plane to its initial state: original color, no freeze,
  /// no cooldown, back to default lane position.
  Future<void> resetToDefault() async {
    planeColor    = _defaultColor;
    currentLane   = (_defaultColor == PlaneColor.blue) ? 0 : 3;
    isFrozen      = false;
    _freezeTimer  = 0.0;
    _shootCooldown = 0.0;
    paint.color   = paint.color.withValues(alpha: 1.0);
    await _loadSprite();
  }

  // ── Private ────────────────────────────────────────────────────────────────
  Future<void> _loadSprite() async {
    sprite = await game.loadSprite(
      planeColor == PlaneColor.blue ? Assets.bluePlane : Assets.redPlane,
    );
  }
}
