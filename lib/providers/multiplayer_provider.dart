// lib/providers/multiplayer_provider.dart
//
// CHANGES vs previous version:
//  1. _readyRetryTimer interval reduced from 500ms → 200ms.
//     With 500ms retries, two players could sit at the "found" screen for
//     up to 1 second waiting for the handshake. 200ms makes the start feel
//     nearly instant.
//  2. No other logic changes — matchmaking, private match, life/win tracking
//     all unchanged.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nakama/nakama.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/op_code.dart';
import 'package:color4planes/models/match_state.dart';
import 'package:color4planes/providers/auth_provider.dart';
import 'package:color4planes/providers/stats_provider.dart';
import 'package:color4planes/services/nakama_service.dart';

class MultiplayerNotifier extends Notifier<MatchState> {
  StreamSubscription<MatchmakerMatched>?  _matchmakerSub;
  StreamSubscription<MatchPresenceEvent>? _presenceSub;
  Timer?  _readyRetryTimer;
  String? _ticket;

  bool _iAmReady      = false;
  bool _opponentReady = false;

  @override
  MatchState build() => const MatchState();

  // ── Matchmaking ────────────────────────────────────────────────────────────

  Future<void> startMatchmaking() async {
    await _cleanup(leaveMatchToo: false);
    _iAmReady      = false;
    _opponentReady = false;

    state = MatchState(status: MatchStatus.searching, myUserId: _myUserId);

    _matchmakerSub = NakamaService.instance.socket.onMatchmakerMatched.listen(
      _onMatchFound,
    );

    try {
      final ticket = await NakamaService.instance.joinMatchmaker();
      _ticket = ticket.ticket;
    } catch (e) {
      debugPrint('[MP] Matchmaker error: $e → reconnecting');
      try {
        await NakamaService.instance.disconnect();
        await NakamaService.instance.connectSocket();
        final ticket = await NakamaService.instance.joinMatchmaker();
        _ticket = ticket.ticket;
      } catch (retryE) {
        debugPrint('[MP] Matchmaker retry failed: $retryE');
        state = const MatchState(status: MatchStatus.idle);
      }
    }
  }

  Future<void> _onMatchFound(MatchmakerMatched matched) async {
    _matchmakerSub?.cancel();
    _matchmakerSub = null;
    _iAmReady      = false;
    _opponentReady = false;

    final myId     = state.myUserId;
    final opponent = matched.users.firstWhere((u) => u.presence.userId != myId);

    state = state.copyWith(
      status:       MatchStatus.found,
      opponentId:   opponent.presence.userId,
      opponentName: opponent.presence.username,
    );

    final match = await NakamaService.instance.joinMatch(
      matched.matchId ?? '',
      token: matched.token,
    );
    state = state.copyWith(matchId: match.matchId);

    _presenceSub = NakamaService.instance.socket.onMatchPresence.listen(
      _onPresenceEvent,
    );
    debugPrint('[MP] Match joined: ${match.matchId}');
  }

  void _onPresenceEvent(MatchPresenceEvent event) {
    if (state.status == MatchStatus.waitingForFriend) {
      for (final p in event.joins) {
        if (p.userId != state.myUserId) {
          state = state.copyWith(
            status:       MatchStatus.found,
            opponentId:   p.userId,
            opponentName: p.username,
          );
          return;
        }
      }
    }

    if (state.status == MatchStatus.idle || state.status == MatchStatus.finished) return;

    final opponentLeft = event.leaves.any((p) => p.userId == state.opponentId);
    if (opponentLeft) {
      debugPrint('[MP] Opponent disconnected');
      _readyRetryTimer?.cancel();
      state = state.copyWith(
        status:               MatchStatus.finished,
        winnerId:             state.myUserId,
        opponentDisconnected: true,
      );
    }
  }

  // ── Both ready → start immediately (no countdown) ─────────────────────────

  void _startPlaying() {
    if (state.status == MatchStatus.playing) return;
    _readyRetryTimer?.cancel();
    debugPrint('[MP] Both players ready → START PLAYING');
    state = MatchState(
      status:        MatchStatus.playing,
      matchId:       state.matchId,
      myUserId:      state.myUserId,
      opponentId:    state.opponentId,
      opponentName:  state.opponentName,
      myLives:       MultiplayerConfig.startingLives,
      opponentLives: MultiplayerConfig.startingLives,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API — called by MultiplayerMatchWorld
  // ══════════════════════════════════════════════════════════════════════════

  /// Called by MultiplayerMatchWorld at the end of onLoad().
  /// FIX: retry interval reduced from 500ms → 200ms for much faster startup.
  Future<void> onLocalReady() async {
    _iAmReady = true;
    await _send(MatchOpCode.playerReady, {});
    debugPrint('[MP] Local ready — retrying every 200ms');

    _readyRetryTimer?.cancel();
    _readyRetryTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (state.status != MatchStatus.found) { t.cancel(); return; }
      _send(MatchOpCode.playerReady, {});
    });

    if (_opponentReady) _startPlaying();
  }

  /// Called when MatchOpCode.playerReady arrives from the opponent.
  void onOpponentReady() {
    if (_opponentReady) return;
    _opponentReady = true;
    debugPrint('[MP] Opponent ready received');
    if (_iAmReady) {
      _send(MatchOpCode.playerReady, {});
      _startPlaying();
    }
  }

  // ── Gameplay ───────────────────────────────────────────────────────────────

  Future<void> reportLifeLost() async {
    if (!state.isPlaying) return;
    final newLives = (state.myLives - 1).clamp(0, MultiplayerConfig.startingLives);
    state = state.copyWith(myLives: newLives);
    await _send(MatchOpCode.lifeLost, {'lives': newLives});
    _checkWin();
  }

  void setOpponentLives(int lives) {
    if (!state.isPlaying) return;
    state = state.copyWith(opponentLives: lives);
    _checkWin();
  }

  void onOpponentGameOver(String winnerId) {
    if (state.isFinished || !state.isPlaying) return;
    state = state.copyWith(status: MatchStatus.finished, winnerId: winnerId);
  }

  void sendBulletFired({required String color, required int lane}) =>
      _send(MatchOpCode.bulletFired, {'color': color, 'lane': lane});

  void sendColorSwapped() => _send(MatchOpCode.colorSwapped, {});

  void sendLaneSwitched({required bool isLeft, required int lane}) =>
      _send(MatchOpCode.laneSwitched, {'is_left': isLeft, 'lane': lane});

  void sendPlaneHit({required bool isLeft}) =>
      _send(MatchOpCode.planeHit, {'is_left': isLeft});

  // ── Win condition ──────────────────────────────────────────────────────────

  void _checkWin() {
    if (!state.isPlaying) return;
    if (state.myLives <= 0) {
      _endGame(winnerId: state.opponentId ?? '');
    } else if (state.opponentLives <= 0)
      _endGame(winnerId: state.myUserId ?? '');
  }

  Future<void> _endGame({required String winnerId}) async {
    if (!state.isPlaying) return;
    state = state.copyWith(status: MatchStatus.finished, winnerId: winnerId);
    await _send(MatchOpCode.gameOver, {'winner_id': winnerId});
    ref.read(statsProvider.notifier).recordMultiplayerGame(
      won: winnerId == state.myUserId,
    );
  }

  // ── Cancel matchmaking ─────────────────────────────────────────────────────

  Future<void> cancelMatchmaking() async {
    _matchmakerSub?.cancel();
    _matchmakerSub = null;
    if (_ticket != null) {
      try { await NakamaService.instance.cancelMatchmaker(_ticket!); } catch (_) {}
      _ticket = null;
    }
    state = const MatchState();
  }

  // ── Private matches ────────────────────────────────────────────────────────

  Future<String?> createPrivateMatch() async {
    await _cleanup(leaveMatchToo: false);
    _iAmReady = false;
    _opponentReady = false;
    final myId = _myUserId;
    try {
      return await _attemptCreatePrivateMatch(myId);
    } catch (e) {
      debugPrint('[MP] Create private match error: $e');
      try {
        await NakamaService.instance.disconnect();
        await NakamaService.instance.connectSocket();
        return await _attemptCreatePrivateMatch(myId);
      } catch (_) {
        state = const MatchState(status: MatchStatus.idle);
        return null;
      }
    }
  }

  Future<String?> _attemptCreatePrivateMatch(String? myId) async {
    final matchId = await NakamaService.instance.createPrivateMatch();
    state = MatchState(
      status:   MatchStatus.waitingForFriend,
      matchId:  matchId,
      myUserId: myId,
    );
    _presenceSub = NakamaService.instance.socket.onMatchPresence.listen(
      _onPresenceEvent,
    );
    debugPrint('[MP] Private match created: $matchId');
    return matchId;
  }

  Future<bool> joinPrivateMatch(String matchId) async {
    await _cleanup(leaveMatchToo: false);
    _iAmReady = false;
    _opponentReady = false;
    final myId = _myUserId;
    try {
      return await _attemptJoinPrivateMatch(matchId, myId);
    } catch (e) {
      debugPrint('[MP] Join private match error: $e');
      try {
        await NakamaService.instance.disconnect();
        await NakamaService.instance.connectSocket();
        return await _attemptJoinPrivateMatch(matchId, myId);
      } catch (_) {
        state = const MatchState(status: MatchStatus.idle);
        return false;
      }
    }
  }

  Future<bool> _attemptJoinPrivateMatch(String matchId, String? myId) async {
    final match = await NakamaService.instance.joinPrivateMatch(matchId);
    String? opponentId;
    String? opponentName;
    for (final p in match.presences) {
      if (p.userId != myId) {
        opponentId   = p.userId;
        opponentName = p.username;
        break;
      }
    }
    state = MatchState(
      status:       MatchStatus.found,
      matchId:      match.matchId,
      myUserId:     myId,
      opponentId:   opponentId,
      opponentName: opponentName,
    );
    _presenceSub = NakamaService.instance.socket.onMatchPresence.listen(
      _onPresenceEvent,
    );
    debugPrint('[MP] Joined private match: ${match.matchId}');
    return true;
  }

  Future<void> leaveMatch() async {
    await _cleanup(leaveMatchToo: true);
    _iAmReady = _opponentReady = false;
    state = const MatchState();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _cleanup({required bool leaveMatchToo}) async {
    _readyRetryTimer?.cancel();
    _readyRetryTimer  = null;
    _matchmakerSub?.cancel();
    _matchmakerSub    = null;
    _presenceSub?.cancel();
    _presenceSub      = null;
    if (leaveMatchToo && state.matchId != null) {
      try {
        await NakamaService.instance.leaveMatch(state.matchId!);
      } catch (e) {
        debugPrint('[MP] Safe leave ignored: $e');
      }
    }
  }

  Future<void> _send(int opCode, Map<String, dynamic> payload) async {
    if (state.matchId == null) return;
    try {
      await NakamaService.instance.sendMatchData(
        matchId: state.matchId!,
        opCode:  opCode,
        data:    jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[MP] send error op=$opCode: $e');
    }
  }

  String? get _myUserId => switch (ref.read(authProvider)) {
    AuthLoading()                    => null,
    AuthGuest(user: final u)         => u.id,
    AuthAuthenticated(user: final u) => u.id,
  };
}

final multiplayerProvider = NotifierProvider<MultiplayerNotifier, MatchState>(
  MultiplayerNotifier.new,
);