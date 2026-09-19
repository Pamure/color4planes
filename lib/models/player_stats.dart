// lib/models/player_stats.dart
//
// Pure data class — no Flutter imports.
// Serializable via toJson/fromJson so it travels over network.

class PlayerStats {
  final int    totalGamesPlayed;
  final int    totalKills;
  final int    totalWins;      // multiplayer wins
  final int    totalLosses;    // multiplayer losses
  final int    bestScore;
  final int    totalSecondsPlayed;
  final int    totalShotsFired;

  const PlayerStats({
    this.totalGamesPlayed   = 0,
    this.totalKills         = 0,
    this.totalWins          = 0,
    this.totalLosses        = 0,
    this.bestScore          = 0,
    this.totalSecondsPlayed = 0,
    this.totalShotsFired    = 0,
  });

  // Computed — not stored, calculated on the fly
  double get winRate {
    final total = totalWins + totalLosses;
    return total == 0 ? 0.0 : totalWins / total * 100;
  }

  String get totalTimePlayed {
    final h = totalSecondsPlayed ~/ 3600;
    final m = (totalSecondsPlayed % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${totalSecondsPlayed % 60}s';
  }

  Map<String, dynamic> toJson() => {
    'total_games':   totalGamesPlayed,
    'total_kills':   totalKills,
    'total_wins':    totalWins,
    'total_losses':  totalLosses,
    'best_score':    bestScore,
    'total_seconds': totalSecondsPlayed,
    'total_shots':   totalShotsFired,
  };

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
    totalGamesPlayed:   json['total_games']   as int? ?? 0,
    totalKills:         json['total_kills']   as int? ?? 0,
    totalWins:          json['total_wins']    as int? ?? 0,
    totalLosses:        json['total_losses']  as int? ?? 0,
    bestScore:          json['best_score']    as int? ?? 0,
    totalSecondsPlayed: json['total_seconds'] as int? ?? 0,
    totalShotsFired:    json['total_shots']   as int? ?? 0,
  );

  PlayerStats copyWith({int? totalGamesPlayed, int? totalKills, int? totalWins,
      int? totalLosses, int? bestScore, int? totalSecondsPlayed, int? totalShotsFired}) =>
    PlayerStats(
      totalGamesPlayed:   totalGamesPlayed   ?? this.totalGamesPlayed,
      totalKills:         totalKills         ?? this.totalKills,
      totalWins:          totalWins          ?? this.totalWins,
      totalLosses:        totalLosses        ?? this.totalLosses,
      bestScore:          bestScore          ?? this.bestScore,
      totalSecondsPlayed: totalSecondsPlayed ?? this.totalSecondsPlayed,
      totalShotsFired:    totalShotsFired    ?? this.totalShotsFired,
    );
}
