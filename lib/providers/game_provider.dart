// lib/providers/game_provider.dart

//
// ── FIX #1: THE 60FPS UI REBUILD TRAP ────────────────────────────────────────
//
// WHAT CHANGED:
//   OLD: updateTime(dt) called every frame → 60 notifyListeners/sec → battery drain
//   NEW: survivalTime is NOT in this provider.
//        Time is tracked as a plain double inside MainView (Flame).
//        A Flame TextComponent reads that double and updates its text 1x/sec.
//        This provider is only called for RARE events:
//          - Ship destroyed (maybe 2-3 times per second at most)
//          - Game over (once)
//
// RULE OF THUMB:
//   If it happens more than ~5 times per second, don't call a Riverpod provider.
//   Track it locally in Flame and sync to providers on meaningful milestones.
// ─────────────────────────────────────────────────────────────────────────────


import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/providers/stats_provider.dart';
import 'package:color4planes/services/nakama_service.dart';

enum GameStatus { idle, countdown, playing, paused, gameOver }

// ── Game Session State (Data Class - Unchanged) ──────────────────────────────
class GameSessionState {
  final GameStatus status;
  final int        score;
  final int        shipsDestroyed;
  final String     finalTime;   // Only populated at game over
  final int        totalShots;  // Only populated at game over
  final int        countdownSeconds; // Added for the 3..2..1 GO!

  const GameSessionState({
    this.status         = GameStatus.idle,
    this.score          = 0,
    this.shipsDestroyed = 0,
    this.finalTime      = '00:00',
    this.totalShots     = 0,
    this.countdownSeconds = 0,
  });

  bool get isPlaying => status == GameStatus.playing;

  double get accuracy =>
      totalShots == 0 ? 0.0 : (shipsDestroyed / totalShots) * 100;

  Map<String, String> get summary => {
    'Score':           score.toString(),
    'Ships Destroyed': shipsDestroyed.toString(),
    'Survival Time':   finalTime,
    'Accuracy':        '${accuracy.toStringAsFixed(1)}%',
    'Shots Fired':     totalShots.toString(),
  };

  GameSessionState copyWith({
    GameStatus? status,
    int?        score,
    int?        shipsDestroyed,
    String?     finalTime,
    int?        totalShots,
    int?        countdownSeconds,
  }) => GameSessionState(
    status:         status         ?? this.status,
    score:          score          ?? this.score,
    shipsDestroyed: shipsDestroyed ?? this.shipsDestroyed,
    finalTime:      finalTime      ?? this.finalTime,
    totalShots:     totalShots     ?? this.totalShots,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
  );
}

// ── NEW Game Session Notifier (Migrated to Notifier) ─────────────────────────

class GameSessionNotifier extends Notifier<GameSessionState> {
  Timer? _countdownTimer;

  // 1. build() replaces the constructor. Returns initial state.
  @override
  GameSessionState build() {
    return const GameSessionState();
  }

  void startGame() {
    // Reset all stats for the new game
    state = const GameSessionState();
    _startCountdown();
  }

  void _startCountdown() {
    state = state.copyWith(status: GameStatus.countdown, countdownSeconds: 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = state.countdownSeconds - 1;
      if (next <= 0) {
        t.cancel();
        state = state.copyWith(status: GameStatus.playing, countdownSeconds: 0);
      } else {
        state = state.copyWith(countdownSeconds: next);
      }
    });
  }

  // Called by Bullet.onCollisionStart
// what is basepoints
  void addScore(int basePoints, double multiplier) {
    if (!state.isPlaying) return;
    final gained   = (basePoints * multiplier).round();
    final newScore = state.score + gained;
    state = state.copyWith(score: newScore);

    // 2. In new Riverpod, we use 'ref' directly (it's built-in) dont know why we using
    // update high score in auth provider oh cause its a user details okok .
    ref.read(authProvider.notifier).updateHighScore(newScore);
  }

  void recordShipDestroyed() {
    state = state.copyWith(shipsDestroyed: state.shipsDestroyed + 1);
  }

  void triggerGameOver({required String survivedFor, required int shotsFired, required double secondsPlayed}) {
    if (state.status == GameStatus.gameOver) return;
    _countdownTimer?.cancel();
    state = state.copyWith(
      status:     GameStatus.gameOver,
      finalTime:  survivedFor,
      totalShots: shotsFired,
    );

    // Record stats and submit score (fire-and-forget, don't block UI)
    ref.read(statsProvider.notifier).recordSoloGame(
      kills:         state.shipsDestroyed,
      score:         state.score,
      secondsPlayed: secondsPlayed.toInt(),
      shotsFired:    shotsFired,
    );
    NakamaService.instance.submitScore(state.score);
  }

  void pause() {
    _countdownTimer?.cancel();
    if (state.isPlaying || state.status == GameStatus.countdown) {
      state = state.copyWith(status: GameStatus.paused);
    }
  }

  void resume() {
    if (state.status == GameStatus.paused) {
      _startCountdown();
    }
  }
}

// ── NEW Provider Definition ──────────────────────────────────────────────────

// 3. Use NotifierProvider instead of StateNotifierProvider
final gameSessionProvider = NotifierProvider<GameSessionNotifier, GameSessionState>(GameSessionNotifier.new);
