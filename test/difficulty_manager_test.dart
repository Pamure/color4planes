import 'package:flutter_test/flutter_test.dart';
import 'package:color4planes/managers/difficulty_manager.dart';

void main() {
  group('DifficultyManager Tests (Wave Curve) -', () {
    late DifficultyManager manager;

    setUp(() {
      manager = DifficultyManager();
    });

    test('Initial difficulty should be Boy (Lowest)', () {
      expect(manager.difficultyLabel, 'BOY');
      // At gameTime 0, expected spawn is spawnP1Start (0.8) and base speed
      expect(manager.spawnRate, closeTo(0.8, 0.05));
      expect(manager.scoreMultiplier, 1.0);
    });

    test('Transitions from Boy to Man at 30 seconds', () {
      manager.update(29.0);
      expect(manager.difficultyLabel, 'BOY', reason: 'Should still be Boy at 29s');

      manager.update(1.0);
      expect(manager.difficultyLabel, 'MAN', reason: 'Should transition to Man at 30s');
    });

    test('Transitions from Man to Sorcerer at 65 seconds', () {
      manager.update(65.0);
      expect(manager.difficultyLabel, 'SORCERER', reason: 'Should be Sorcerer at 65s');
      expect(manager.scoreMultiplier, 2.0);
    });

    test('Transitions from Sorcerer to Supreme at 130 seconds', () {
      manager.update(130.0);
      expect(manager.difficultyLabel, 'SUPREME', reason: 'Should be Supreme at 130s');
      expect(manager.scoreMultiplier, 3.0);
    });

    test('Breather wave: spawn rate dips on phase start', () {
      // End of phase 1
      manager.update(29.9);
      final p1Peak = manager.spawnRate; // ~1.5
      expect(p1Peak, closeTo(1.5, 0.1));

      // Start of phase 2 (breather)
      manager.update(0.2); // Now at 30.1s
      final p2Start = manager.spawnRate; // ~1.25
      
      // The spawn rate should be LOWER at the start of phase 2 than the absolute end of phase 1
      expect(p2Start, lessThan(p1Peak), reason: 'Spawn rate should dip to give players breather');
    });

    test('Reset puts manager back to initial conditions', () {
      manager.update(150.0);
      expect(manager.difficultyLabel, 'SUPREME');

      manager.reset();
      expect(manager.difficultyLabel, 'BOY');
      expect(manager.scoreMultiplier, 1.0);
    });
  });
}
