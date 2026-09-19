import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:color4planes/managers/input_manager.dart';

void main() {
  group('InputManager Swipe Tests -', () {
    late InputManager input;
    bool leftShooted = false;
    bool rightShooted = false;
    bool colorsSwapped = false;
    bool? switchLeft;
    bool? moveCenter;
    bool? toggleLeft;

    setUp(() {
      leftShooted = false;
      rightShooted = false;
      colorsSwapped = false;
      switchLeft = null;
      moveCenter = null;
      toggleLeft = null;

      input = InputManager(
        onLeftShoot: () => leftShooted = true,
        onRightShoot: () => rightShooted = true,
        onSwapColors: () => colorsSwapped = true,
        onLaneSwitch: (left, center) {
          switchLeft = left;
          moveCenter = center;
        },
        onToggleLane: (left) => toggleLeft = left,
      );

      input.updateScreenSize(Vector2(500, 800));
      // Give planes dummy positions
      input.updatePlanePositions(Vector2(100, 700), Vector2(400, 700), tapRadius: 55.0);
    });

    test('Swipe Down triggers color swap', () {
      final delta = Vector2(0, 50); // Vertical down
      final start = Vector2(250, 400); // Middle of screen

      input.handleDragEnd(delta, start);

      expect(colorsSwapped, true);
    });

    test('Swipe Up triggers color swap', () {
      final delta = Vector2(0, -60); // Vertical up
      final start = Vector2(250, 400);

      input.handleDragEnd(delta, start);

      expect(colorsSwapped, true);
    });

    test('Swipe Left on left side of screen moves left plane OUTWARD', () {
      final delta = Vector2(-50, 0); // Swipe left
      final start = Vector2(100, 400); // Left half

      input.handleDragEnd(delta, start);

      expect(switchLeft, true);
      expect(moveCenter, false); // OUTWARD (not toward center)
    });

    test('Swipe Right on left side of screen moves left plane TOWARD CENTER', () {
      final delta = Vector2(50, 0); // Swipe right
      final start = Vector2(100, 400); // Left half

      input.handleDragEnd(delta, start);

      expect(switchLeft, true);
      expect(moveCenter, true); // TOWARD CENTER
    });

    test('Swipe Left on right side of screen moves right plane TOWARD CENTER', () {
      final delta = Vector2(-50, 0); // Swipe left
      final start = Vector2(400, 400); // Right half

      input.handleDragEnd(delta, start);

      expect(switchLeft, false); // Right plane
      expect(moveCenter, true); // TOWARD CENTER
    });

    test('Swipe Right on right side of screen moves right plane OUTWARD', () {
      final delta = Vector2(50, 0); // Swipe right
      final start = Vector2(400, 400); // Right half

      input.handleDragEnd(delta, start);

      expect(switchLeft, false); // Right plane
      expect(moveCenter, false); // OUTWARD
    });
  });
}
