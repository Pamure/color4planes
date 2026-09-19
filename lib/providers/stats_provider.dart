 // lib/providers/stats_provider.dart
//
// Owns the PlayerStats state. Loads from Nakama on startup.
// Called after each game/match to update and save.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color4planes/models/player_stats.dart';
import 'package:color4planes/services/nakama_service.dart';

class StatsNotifier extends AsyncNotifier<PlayerStats> {
  // AsyncNotifier is like Notifier but build() can return a Future.
  // State becomes AsyncValue<PlayerStats> which has .loading, .data, .error states.
  // Use ref.watch(statsProvider) in UI and check .when(data:, loading:, error:)

  @override
  Future<PlayerStats> build() async {
    // Runs once on first access. Loads stats from server.
    return NakamaService.instance.loadStats();
  }

  /// Called after single-player game ends.
  Future<void> recordSoloGame({
    required int kills,
    required int score,
    required int secondsPlayed,
    required int shotsFired,
  }) async {
    final current = state.value?? const PlayerStats();
    final updated = current.copyWith(
      totalGamesPlayed:   current.totalGamesPlayed + 1,
      totalKills:         current.totalKills + kills,
      bestScore:          score > current.bestScore ? score : current.bestScore,
      totalSecondsPlayed: current.totalSecondsPlayed + secondsPlayed,
      totalShotsFired:    current.totalShotsFired + shotsFired,
    );
    state = AsyncValue.data(updated);  // update local state immediately
    await NakamaService.instance.saveStats(updated);  // then sync to server
  }

  /// Called after multiplayer match ends.
  Future<void> recordMultiplayerGame({required bool won}) async {
    final current = state.value?? const PlayerStats();
    final updated = current.copyWith(
      totalGamesPlayed: current.totalGamesPlayed + 1,
      totalWins:        won ? current.totalWins + 1 : current.totalWins,
      totalLosses:      won ? current.totalLosses : current.totalLosses + 1,
    );
    state = AsyncValue.data(updated);
    await NakamaService.instance.saveStats(updated);
  }
}

final statsProvider = AsyncNotifierProvider<StatsNotifier, PlayerStats>(StatsNotifier.new);
