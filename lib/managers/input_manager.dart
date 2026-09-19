// lib/managers/input_manager.dart
//
// INPUT ARCHITECTURE — how gestures become game actions:
//
//   FlameGame.onDragEnd
//       → inputManager.handleDragEnd(delta, start)
//           → classifies gesture
//               → fires one of: onLeftShoot / onRightShoot /
//                               onSwapColors / onLaneSwitch / onToggleLane
//
// InputManager's ONLY job is gesture classification.
// It never touches game state — no planes, bullets, or providers.
// The MainView / MultiplayerMatchWorld own state and supply the callbacks.
//
// ── TOUCH CONTROLS ────────────────────────────────────────────────────────────
//
//  TAP near left plane      → toggle left plane  (lane 0 ↔ 1)
//  TAP near right plane     → toggle right plane (lane 2 ↔ 3)
//  TAP anywhere else        → shoot (left half = left gun, right half = right gun)
//  SWIPE horizontal (left)  → lane switch: explicit direction (left half = left plane, right half = right plane)
//  SWIPE vertical (any dir) → color swap
//
// WHY both swipe AND tap-to-toggle work with zero conflict:
//   Both paths live inside handleDragEnd() and are classified by magnitude first.
//   A "tap near a plane" that moves far enough horizontally is a swipe, not a tap.
//   A short movement near a plane is a tap.
//   These two cases are mutually exclusive — the magnitude check is the gate.
//   There is NO ambiguity and NO double-trigger.
//
// ── KEYBOARD ──────────────────────────────────────────────────────────────────
//  W / ↑        → shoot left / right
//  Space        → swap colors
//  A / D        → left plane outer / inner lane
//  ← / →        → right plane inner / outer lane

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:color4planes/core/constants.dart';

class InputManager {

  // ── Callbacks ──────────────────────────────────────────────────────────────
  // The game world wires these up — InputManager never knows what happens when they fire.

  final void Function()           onLeftShoot;
  final void Function()           onRightShoot;
  final void Function()           onSwapColors;

  /// Keyboard-style lane switch — caller specifies direction explicitly.
  /// (isLeft, moveTowardCenter)
  final void Function(bool, bool) onLaneSwitch;

  /// Touch plane-tap toggle — caller decides which lane to go to based on current state.
  /// (isLeft) — true = left plane, false = right plane
  final void Function(bool)       onToggleLane;

  // ── Internal state ─────────────────────────────────────────────────────────
  Vector2 _screenSize = Vector2.zero();

  // Plane positions in screen coordinates. Null until first onGameResize.
  // Updated by the game world every time a plane moves.
  Vector2? _leftPlanePos;
  Vector2? _rightPlanePos;

  // Tap-to-toggle radius in pixels. Set via updatePlanePositions().
  // Default 55px is safe before the first call.
  double _planeTapRadius = 55.0;

  // ── Constructor ────────────────────────────────────────────────────────────
  InputManager({
    required this.onLeftShoot,
    required this.onRightShoot,
    required this.onSwapColors,
    required this.onLaneSwitch,
    required this.onToggleLane,
  });

  // ── Layout updates (called by game world) ──────────────────────────────────
  void updateScreenSize(Vector2 size) => _screenSize = size;

  /// Tell InputManager where the planes currently are.
  ///
  /// Call after:
  ///   - onGameResize  (initial layout)
  ///   - any lane switch (plane moved to new x position)
  ///   - game restart  (planes reset to defaults)
  ///
  /// [tapRadius] — pixels from plane center that count as "tapped on plane".
  /// Use laneWidth * 0.85: comfortably tappable, won't overlap the other plane's zone.
  void updatePlanePositions(
    Vector2? leftPos,
    Vector2? rightPos, {
    required double tapRadius,
  }) {
    // Clone: we store a snapshot. The plane's own Vector2 will keep changing.
    _leftPlanePos   = leftPos?.clone();
    _rightPlanePos  = rightPos?.clone();
    _planeTapRadius = tapRadius;
  }

  // ── Single entry point for ALL touch input ─────────────────────────────────
  //
  // Called from FlameGame.onDragEnd ONLY — never from onTapDown.
  // Waiting until drag end means we always know the full gesture before acting.
  //
  // delta = dragCurrent - dragStart  (net movement vector)
  // start = where the finger first landed
  void handleDragEnd(Vector2 delta, Vector2 start) {
    final absX      = delta.x.abs();
    final absY      = delta.y.abs();
    // Dominant axis — whichever moved more decides the gesture type.
    final magnitude = absX > absY ? absX : absY;

    // ── GATE 1: SHORT MOVEMENT → TAP ─────────────────────────────────────
    // Finger barely moved. No swipe. Decide by where it landed.
    if (magnitude < GameConfig.minSwipeDistance) {
      // Priority 1: did the tap land near the left plane?
      if (_leftPlanePos != null &&
          _squaredDist(start, _leftPlanePos!) < _planeTapRadius * _planeTapRadius) {
        onToggleLane(true);    // left plane → toggle lane 0 ↔ 1
        return;
      }
      // Priority 2: did the tap land near the right plane?
      if (_rightPlanePos != null &&
          _squaredDist(start, _rightPlanePos!) < _planeTapRadius * _planeTapRadius) {
        onToggleLane(false);   // right plane → toggle lane 2 ↔ 3
        return;
      }
      // Priority 3: general tap → shoot
      if (start.x < _screenSize.x / 2) {
        onLeftShoot();
      } else {
        onRightShoot();
      }
      return;
    }

    // ── GATE 2: REAL SWIPE ────────────────────────────────────────────────
    // Finger moved far enough to be a deliberate gesture.
    // absX vs absY tells us which axis was dominant.

    if (absX > absY) {
      // ── HORIZONTAL SWIPE → LANE SWITCH (explicit direction) ─────────────
      // Which plane to move is decided by which half of the screen the finger started on.
      // Direction of movement decides which lane to go to.
      //
      // Left half:
      //   swipe right → toward center  (lane 0 → 1)
      //   swipe left  → toward edge    (lane 1 → 0)
      // Right half:
      //   swipe left  → toward center  (lane 3 → 2)
      //   swipe right → toward edge    (lane 2 → 3)
      final isLeft           = start.x < _screenSize.x / 2;
      final movingRight      = delta.x > 0;
      final moveTowardCenter = isLeft ? movingRight : !movingRight;
      onLaneSwitch(isLeft, moveTowardCenter);

    } else if (absY > absX) {
      // ── VERTICAL SWIPE → COLOR SWAP ───────────────────────────────────
      // Direction (up/down) doesn't matter — any vertical swipe swaps colors.
      onSwapColors();
    }
    // Pure 45° diagonal (absX == absY) → ignore. Ambiguous intent.
  }

  // ── Keyboard ───────────────────────────────────────────────────────────────
  // Full directional control for PC. Unchanged.
  bool handleKeyPress(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.keyW:       onLeftShoot();              return true;
      case LogicalKeyboardKey.arrowUp:    onRightShoot();             return true;
      case LogicalKeyboardKey.space:      onSwapColors();             return true;
      case LogicalKeyboardKey.keyA:       onLaneSwitch(true,  false); return true; // left outer
      case LogicalKeyboardKey.keyD:       onLaneSwitch(true,  true);  return true; // left inner
      case LogicalKeyboardKey.arrowLeft:  onLaneSwitch(false, true);  return true; // right inner
      case LogicalKeyboardKey.arrowRight: onLaneSwitch(false, false); return true; // right outer
      default: return false;
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────
  // Squared distance: avoids sqrt, fast for radius checks.
  // Equivalent to: actual_distance < radius  →  dx²+dy² < radius²
  double _squaredDist(Vector2 a, Vector2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }
}
