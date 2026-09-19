//
// Every meaningful game action is an Event.
// WHY: Instead of calling functions directly, you record what happened.
//
// In single-player: events just update local state.
// In multiplayer:   events also get sent over the Nakama socket.
//
// "sealed class" means ONLY these subclasses can exist.
// The compiler will warn you if you forget to handle one in a switch.

// Import only models — no Flutter, no Flame
import 'package:color4planes/models/player_state.dart';

// ── Base Event ──────sealed means k it can only be used in this file only
sealed class GameEvent {
  final String   playerId;
  final DateTime timestamp;

  GameEvent({required this.playerId}) : timestamp = DateTime.now();

  // Every event must be serialisable for network transport
  Map<String, dynamic> toJson();

  // Reconstruct from JSON — called when receiving opponent events from Nakama
  static GameEvent fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'bullet_fired':   return BulletFiredEvent.fromJson(json);
      case 'ship_destroyed': return ShipDestroyedEvent.fromJson(json);
      case 'color_swapped':  return ColorSwappedEvent.fromJson(json);
      case 'lane_switched':  return LaneSwitchedEvent.fromJson(json);
      case 'game_over':      return GameOverEvent.fromJson(json);
      default: throw ArgumentError('Unknown event type: ${json["type"]}');
    }
  }
}

// ── Concrete Events ───────────────────────────────────────────────────────────

class BulletFiredEvent extends GameEvent {
  final PlaneColor color;
  final int        lane;
  final double     xPosition;

  BulletFiredEvent({
    required super.playerId,
    required this.color,
    required this.lane,
    required this.xPosition,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type':      'bullet_fired',
    'player_id': playerId,
    'color':     color.name,
    'lane':      lane,
    'x':         xPosition,
    'ts':        timestamp.millisecondsSinceEpoch,
  };

  factory BulletFiredEvent.fromJson(Map<String, dynamic> j) => BulletFiredEvent(
    playerId:  j['player_id'] as String,
    color:     PlaneColor.values.byName(j['color'] as String),
    lane:      j['lane']      as int,
    xPosition: (j['x']        as num).toDouble(),
  );
}

class ShipDestroyedEvent extends GameEvent {
  final int        lane;
  final PlaneColor shipColor;
  final int        pointsEarned;

  ShipDestroyedEvent({
    required super.playerId,
    required this.lane,
    required this.shipColor,
    required this.pointsEarned,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type':       'ship_destroyed',
    'player_id':  playerId,
    'lane':       lane,
    'ship_color': shipColor.name,
    'points':     pointsEarned,
    'ts':         timestamp.millisecondsSinceEpoch,
  };

  factory ShipDestroyedEvent.fromJson(Map<String, dynamic> j) => ShipDestroyedEvent(
    playerId:     j['player_id']  as String,
    lane:         j['lane']       as int,
    shipColor:    PlaneColor.values.byName(j['ship_color'] as String),
    pointsEarned: j['points']     as int,
  );
}

class ColorSwappedEvent extends GameEvent {
  ColorSwappedEvent({required super.playerId});
// koi bool nahi???/
  @override
  Map<String, dynamic> toJson() => {
    'type':      'color_swapped',
    'player_id': playerId,
    'ts':        timestamp.millisecondsSinceEpoch,
  };

  factory ColorSwappedEvent.fromJson(Map<String, dynamic> j) =>
      ColorSwappedEvent(playerId: j['player_id'] as String);
}

class LaneSwitchedEvent extends GameEvent {
  final bool isLeftPlane;
  final int  newLane;

  LaneSwitchedEvent({
    required super.playerId,
    required this.isLeftPlane,
    required this.newLane,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type':          'lane_switched',
    'player_id':     playerId,
    'is_left_plane': isLeftPlane,
    'new_lane':      newLane,
    'ts':            timestamp.millisecondsSinceEpoch,
  };

  factory LaneSwitchedEvent.fromJson(Map<String, dynamic> j) => LaneSwitchedEvent(
    playerId:    j['player_id']     as String,
    isLeftPlane: j['is_left_plane'] as bool,
    newLane:     j['new_lane']      as int,
  );
}

class GameOverEvent extends GameEvent {
  final int finalScore;

  GameOverEvent({required super.playerId, required this.finalScore});

  @override
  Map<String, dynamic> toJson() => {
    'type':        'game_over',
    'player_id':   playerId,
    'final_score': finalScore,
    'ts':          timestamp.millisecondsSinceEpoch,
  };

  factory GameOverEvent.fromJson(Map<String, dynamic> j) => GameOverEvent(
    playerId:   j['player_id']   as String,
    finalScore: j['final_score'] as int,
  );
}
