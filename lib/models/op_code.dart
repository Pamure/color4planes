/// Integer identifiers for real-time match messages.
///
/// Both the sender and receiver use these constants to know what
/// kind of event is being communicated. Think of them as an enum
/// that travels over the wire as a plain int.
///
/// Range: 1–99. Do not use 0 (reserved by Nakama).
abstract class MatchOpCode {
  /// Both players loaded and are ready. Triggers countdown.
  static const int playerReady  = 1;

  /// A plane fired a bullet upward (toward opponent).
  /// Payload: { color, lane, x }
  static const int bulletFired  = 2;

  /// Player swapped their two plane colors.
  /// Payload: {} (empty)
  static const int colorSwapped = 3;

  /// A plane switched to a different lane.
  /// Payload: { is_left, lane }
  static const int laneSwitched = 4;

  /// An opponent bullet reached my bottom edge → I lost a life.
  /// Payload: { lives }  (my remaining lives after the loss)
  static const int lifeLost     = 5;

  /// An opponent bullet hit one of my plane hitboxes → plane frozen.
  /// Payload: { is_left }  (which of my planes got hit)
  static const int planeHit     = 6;

  /// The game has ended. One player has 0 lives.
  /// Payload: { winner_id }
  static const int gameOver     = 7;

  /// Both players agreed to restart the game in the same room.
  static const int rematchReady = 8;
}
