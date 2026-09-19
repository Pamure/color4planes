/// The lifecycle stages of a multiplayer match.
enum MatchStatus {
  idle,              // Not in any match (default)
  searching,         // In matchmaker queue — waiting for opponent
  waitingForFriend,  // Host created private match — waiting for friend to join
  found,             // Match found — transitioning to game
  countdown,         // 3-2-1 before game begins
  playing,           // Game is live
  finished,          // Someone reached 0 lives or disconnected
}

/// Complete state of an active (or recently finished) multiplayer match.
///
/// Immutable value object — every change creates a new instance via copyWith().
class MatchState {
  final MatchStatus status;
  final String?     matchId;
  final String?     myUserId;
  final String?     opponentId;
  final String?     opponentName;
  final int         myLives;
  final int         opponentLives;
  final int         countdownSeconds;
  final String?     winnerId;
  final bool        opponentDisconnected; // true when opponent dropped mid-game

  const MatchState({
    this.status                = MatchStatus.idle,
    this.matchId,
    this.myUserId,
    this.opponentId,
    this.opponentName,
    this.myLives               = 3,
    this.opponentLives         = 3,
    this.countdownSeconds      = 3,
    this.winnerId,
    this.opponentDisconnected  = false,
  });

  bool get iAmWinner  => winnerId != null && winnerId == myUserId;
  bool get iAmLoser   => winnerId != null && winnerId != myUserId;
  bool get isPlaying  => status == MatchStatus.playing;
  bool get isFinished => status == MatchStatus.finished;
  bool get inMatch    => status != MatchStatus.idle;

  MatchState copyWith({
    MatchStatus? status,
    String?      matchId,
    String?      myUserId,
    String?      opponentId,
    String?      opponentName,
    int?         myLives,
    int?         opponentLives,
    int?         countdownSeconds,
    String?      winnerId,
    bool?        opponentDisconnected,
  }) =>
      MatchState(
        status:               status               ?? this.status,
        matchId:              matchId              ?? this.matchId,
        myUserId:             myUserId             ?? this.myUserId,
        opponentId:           opponentId           ?? this.opponentId,
        opponentName:         opponentName         ?? this.opponentName,
        myLives:              myLives              ?? this.myLives,
        opponentLives:        opponentLives        ?? this.opponentLives,
        countdownSeconds:     countdownSeconds     ?? this.countdownSeconds,
        winnerId:             winnerId             ?? this.winnerId,
        opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
      );

  @override
  String toString() =>
      'MatchState($status, me:$myLives♥ vs opp:$opponentLives♥, winner:$winnerId, disconnected:$opponentDisconnected)';
}
