// lib/models/leaderboard_entry.dart

class LeaderboardEntry {
  final int    rank;
  final String displayName;
  final String username;
  final int    score;
  final String userId;

  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.username,
    required this.score,
    required this.userId,
  });
}
