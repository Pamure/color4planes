// lib/managers/difficulty_manager.dart
//
// Controls how hard the game is at any point in time.
// REDESIGNED: Implements a "Breather Wave" curve. Instead of an impossible
// vertical wall of difficulty, players get slight respites between phases.

import 'dart:math';
import 'package:color4planes/core/constants.dart';

class DifficultyManager {
  double _gameTime = 0;
  static final _rng = Random();

  void update(double dt) => _gameTime += dt;
  void reset()           => _gameTime = 0;

  double get spawnRate {
    final t = _gameTime;
    
    // Phase 1 (Boy)
    if (t < DifficultyConfig.phase1End) {
      return _lerp(DifficultyConfig.spawnP1Start, DifficultyConfig.spawnP1End, 
            t / DifficultyConfig.phase1End);
    } 
    // Phase 2 (Man)
    else if (t < DifficultyConfig.phase2End) {
      return _lerp(DifficultyConfig.spawnP2Start, DifficultyConfig.spawnP2End, 
            (t - DifficultyConfig.phase1End) / (DifficultyConfig.phase2End - DifficultyConfig.phase1End));
    } 
    // Phase 3 (Sorcerer)
    else if (t < DifficultyConfig.phase3End) {
      return _lerp(DifficultyConfig.spawnP3Start, DifficultyConfig.spawnP3End, 
            (t - DifficultyConfig.phase2End) / (DifficultyConfig.phase3End - DifficultyConfig.phase2End));
    }
    // Phase 4 (Supreme)
    else {
      // Very slow asymptotic rise after Phase 3 ends to prevent instant failure
      final overTime = t - DifficultyConfig.phase3End;
      // Cap at P4Max, taking 60 seconds to reach it
      return _lerp(DifficultyConfig.spawnP4Start, DifficultyConfig.spawnP4Max, min(1.0, overTime / 60));
    }
  }

  double get enemySpeed {
    double base;
    final t = _gameTime;
    if (t < DifficultyConfig.phase1End) {
      base = DifficultyConfig.speedPhase1;
    } else if (t < DifficultyConfig.phase2End) base = DifficultyConfig.speedPhase2;
    else if (t < DifficultyConfig.phase3End) base = DifficultyConfig.speedPhase3;
    else                                     base = DifficultyConfig.speedPhase4;
    
    final variation = DifficultyConfig.speedVarMin + 
        _rng.nextDouble() * (DifficultyConfig.speedVarMax - DifficultyConfig.speedVarMin);
    return base * variation;
  }

  double get scoreMultiplier {
    final t = _gameTime;
    if (t < DifficultyConfig.phase1End)      return DifficultyConfig.multPhase1;
    if (t < DifficultyConfig.phase2End)      return DifficultyConfig.multPhase2;
    if (t < DifficultyConfig.phase3End)      return DifficultyConfig.multPhase3;
    return DifficultyConfig.multPhase4;
  }

  String get difficultyLabel {
    final t = _gameTime;
    if (t < DifficultyConfig.phase1End)      return DifficultyConfig.labelPhase1;
    if (t < DifficultyConfig.phase2End)      return DifficultyConfig.labelPhase2;
    if (t < DifficultyConfig.phase3End)      return DifficultyConfig.labelPhase3;
    return DifficultyConfig.labelPhase4;
  }

  double _lerp(double a, double b, double t) {
    // Smoothstep interpolation makes the transition much less jarring
    final smoothT = t * t * (3 - 2 * t);
    return a + (b - a) * smoothT.clamp(0.0, 1.0);
  }
}
