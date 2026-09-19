// lib/models/user_model.dart
//
// Represents a player. Right now a "user" is just a guest with a UUID.
// Later, Nakama replaces the UUID with a real account ID.
//
// KEY DESIGN: toJson() / fromJson() means this model can travel over a
// network socket. When you call Nakama's auth API, it returns JSON.
// UserModel.fromJson(nakamaJson) gives you a typed object instantly.
// isme koi v flutter ya koi package k hone ki zarurat nahi honi chahieye
class UserModel {
  final String id; // Guest UUID now, Nakama user ID later
  final String displayName; // "Guest" now, chosen name later
  final String username; // Nakama username (for sharing)
  final int highScore;
  final int totalGamesPlayed;
  final int totalKills;

  const UserModel({
    required this.id,
    this.displayName = 'notallowedname',
    this.username = '',
    this.highScore = 0,
    this.totalGamesPlayed = 0,
    this.totalKills = 0,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────
  // toJson: convert this object → Map (for sending over network or saving)

   Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'metadata': {
      'high_score': highScore,
      'total_games_played': totalGamesPlayed,
      'total_kills': totalKills,
    },
  };

  // fromJson: receive raw Map (from Nakama API or SharedPreferences) → typed object
  // The ?. and ?? operators handle missing/null fields gracefully
// so basically factory constructor actually returns a object for us like fromJson is the name
// we put to get so i think it can be used to like get profile info

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? 'notallowedname',
    username: json['username'] as String? ?? '',
    highScore: (json['metadata'] as Map?)?['high_score'] as int? ?? 0,
    totalGamesPlayed:
        (json['metadata'] as Map?)?['total_games_played'] as int? ?? 0,
    totalKills: (json['metadata'] as Map?)?['total_kills'] as int? ?? 0,
  );

  // ── Immutable Update ─────────────────────────────────────────────────────── .
  // copyWith = create a modified copy without mutating the original.
  // This is the Dart/functional way to update objects. mayebe used to update scores and name and all
  UserModel copyWith({
    String? id,
    String? displayName,
    String? username,
    int? highScore,
    int? totalGamesPlayed,
    int? totalKills,
  }) => UserModel(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    username: username ?? this.username,
    highScore: highScore ?? this.highScore,
    totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
    totalKills: totalKills ?? this.totalKills,
  );

  @override
  String toString() => 'UserModel(id: $id, name: $displayName, username: $username, hs: $highScore)';
}
