enum PlaneColor{red,blue}
// this is the state of the player will be used to send to nakama sockets
// we used PlaneColor cause jet.dart would have been something flutter we only
// want pure flutter here
class PlayerState {

  final String playerId;
  final int    score;
  final PlaneColor leftColor;   // Current color of left plane
  final PlaneColor rightColor;  // Current color of right plane
  final int    leftLane;        // 0 or 1
  final int    rightLane;       // 2 or 3
  final bool   isAlive;

  const PlayerState({
    required this.playerId,
    this.score      = 0,
    this.leftColor  = PlaneColor.blue,
    this.rightColor = PlaneColor.red,
    this.leftLane   = 0,
    this.rightLane  = 3,
    this.isAlive    = true,
  });

  Map<String, dynamic> toJson() => {
    'player_id':  playerId,
    'score':      score,
    'left_color': leftColor.name,
    'right_color': rightColor.name,
    'left_lane':  leftLane,
    'right_lane': rightLane,
    'is_alive':   isAlive,
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    playerId:   json['player_id']  as String,// ai is sure this is string j
    score:      json['score']      as int? ?? 0,
    leftColor:  PlaneColor.values.byName(json['left_color']  as String? ?? 'blue'),
    rightColor: PlaneColor.values.byName(json['right_color'] as String? ?? 'red'),
    leftLane:   json['left_lane']  as int? ?? 0,
    rightLane:  json['right_lane'] as int? ?? 3,
    isAlive:    json['is_alive']   as bool? ?? true,
  );

  PlayerState copyWith({
    int?       score,
    PlaneColor? leftColor,
    PlaneColor? rightColor,
    int?       leftLane,
    int?       rightLane,
    bool?      isAlive,
  }) => PlayerState(
    playerId:   playerId,
    score:      score       ?? this.score,
    leftColor:  leftColor   ?? this.leftColor,
    rightColor: rightColor  ?? this.rightColor,
    leftLane:   leftLane    ?? this.leftLane,
    rightLane:  rightLane   ?? this.rightLane,
    isAlive:    isAlive     ?? this.isAlive,
  );



}
