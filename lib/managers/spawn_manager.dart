//dart
// lib/managers/spawn_manager.//dart
//
// Decides WHEN and WHERE alien ships appear.
// Balances color distribution and avoids predictable lane patterns.
//
// ── FIX #3 APPLIED ────────────────────────────────────────────────────────────
// _recentLanes is a class-level List, not created inside update().
// It uses removeAt(0) to trim — no new list allocation each frame.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flame/components.dart';
import 'package:color4planes/components/alien_ship.dart';
import 'package:color4planes/core/constants.dart';
import 'package:color4planes/managers/difficulty_manager.dart';
import 'package:color4planes/models/player_state.dart';

class SpawnManager {
  final DifficultyManager difficultyManager;
  final Component         gameWorld;

  double _timeSinceSpawn = 0;
  int    currentCount    = 0;

  // ── FIX #3: Class-level collections — never re-allocated inside update() ──
  final List<int> _recentLanes = [];
  int _blueCount = 0;
  int _redCount  = 0;
  // ─────────────────────────────────────────────────────────────────────────

  double _gameWidth  = 0;
  double _gameHeight = 0;
  double _startX     = 0;
  double _laneW      = 0;

  final Random _rng = Random();

  SpawnManager({required this.difficultyManager, required this.gameWorld});

  void updateDimensions({required double width, required double height, required double startX, required double laneW}) {
    _gameWidth = width;
    _gameHeight = height;
    _startX = startX;
    _laneW = laneW;
  }

  void update(double dt) {
    if (currentCount >= GameConfig.maxShipsOnScreen) return;
    _timeSinceSpawn += dt;
    final interval = 1.0 / difficultyManager.spawnRate;
    if (_timeSinceSpawn >= interval) {
      _spawnShip();
      _timeSinceSpawn = 0;
    }
  }

  void _spawnShip() {
    final lane  = _chooseLane();
    final color = _chooseColor();
    final speed = difficultyManager.enemySpeed;
    gameWorld.add(AlienShip(
      shipColor:     color,
      lane:          lane,
      startPosition: Vector2(_startX + (lane + 0.5) * _laneW, -AlienShip.shipSize),
      speed:         speed,
    ));
    currentCount++;
    _recentLanes.add(lane);
    if (_recentLanes.length > 3) _recentLanes.removeAt(0); // Trim, no new list
  }

  int _chooseLane() {
    // Prefer lanes not recently used — avoids robots-marching-in-a-line feeling
    final all    = [0, 1, 2, 3];
    final unused = all.where((l) => !_recentLanes.contains(l)).toList();
    final pool   = unused.isNotEmpty ? unused : all;
    return pool[_rng.nextInt(pool.length)];
  }

  PlaneColor _chooseColor() {
    // Force balance when one color is 3+ ahead
    if ((_blueCount - _redCount).abs() >= GameConfig.colorImbalanceCap) {
      if (_blueCount > _redCount) { _redCount++;  return PlaneColor.red; }
      _blueCount++; return PlaneColor.blue;
    }
    if (_rng.nextBool()) { _blueCount++; return PlaneColor.blue; }
    _redCount++; return PlaneColor.red;
  }

  void onShipDestroyed() => currentCount = (currentCount - 1).clamp(0, 999);

  void reset() {
    _timeSinceSpawn = 0;
    currentCount    = 0;
    _recentLanes.clear(); // .clear() — not a new list
    _blueCount = 0;
    _redCount  = 0;
  }
}
