// lib/services/nakama_service.dart
//
import 'dart:convert';
import 'package:color4planes/models/player_stats.dart';
import 'package:color4planes/models/leaderboard_entry.dart';
import 'package:color4planes/models/friend_model.dart';
import 'package:flutter/foundation.dart';
import 'package:nakama/nakama.dart';
import 'package:color4planes/core/env.dart';

class NakamaService {
  NakamaService._();
  static final NakamaService instance = NakamaService._();

  NakamaBaseClient? _client;
  Session? _session;
  NakamaWebsocketClient? _socket;

  // ── Status ────────────────────────────────────────────────────────────────
  bool get isReady => _client != null && _session != null;
  bool get isConnected => _socket != null; // NEW — safe null check
  Session? get session => _session;
  static const String _statsCollection = 'player_stats';
  static const String _statsKey = 'stats';
  // ── Initialize ─────────────────────────────────────────────────────────────
  // AFTER:
  void initialize() {
    _client = NakamaRestApiClient.init(
      host: Env.nakamaHost,
      ssl: Env.nakamaSSL,
      serverKey: Env.serverKey,
      port: Env.nakamaPort,
    );
  }

  NakamaBaseClient get _c {
    if (_client == null) throw StateError('Call initialize() first');
    return _client!;
  }

  Future<void> saveStats(PlayerStats stats) async {
    if (_session == null) return;
    await _c.writeStorageObjects(
      session: _session!,
      objects: [
        StorageObjectWrite(
          collection: _statsCollection,
          key: _statsKey,
          value: jsonEncode(stats.toJson()),
          permissionRead: StorageReadPermission
              .publicRead, // 2 = public read (needed for leaderboard-style features)
          permissionWrite: StorageWritePermission
              .ownerWrite, // 1 = owner only (nobody else can overwrite your stats)
        ),
      ],
    );
  }

  /// Load player stats from Nakama cloud storage
  Future<PlayerStats> loadStats() async {
    if (_session == null) return const PlayerStats();
    final result = await _c.readStorageObjects(
      session: _session!,
      objectIds: [
        StorageObjectId(
          collection: _statsCollection,
          key: _statsKey,
          userId: _session!.userId, // read MY own stats
        ),
      ],
    );
    if (result.isEmpty) {
      return const PlayerStats();
    } // first time, no data yet

    try {
      final json = jsonDecode(result.first.value) as Map<String, dynamic>;
      return PlayerStats.fromJson(json);
    } catch (_) {
      return const PlayerStats(); // corrupt data → return empty
    }
  }

  // ── Authentication ──────────────────────────────────────────────────────────
  Future<Session> authenticate(String deviceId) async {
    _session = await _c.authenticateDevice(deviceId: deviceId, create: true);
    return _session!;
  }

  // ── WebSocket ───────────────────────────────────────────────────────────────
  Future<NakamaWebsocketClient> connectSocket() async {
    if (_session == null) throw StateError('Call authenticate() first');
    _socket = NakamaWebsocketClient.init(
      host: Env.nakamaHost,
      ssl: Env.nakamaSSL,
      port: Env.nakamaPort,
      token: _session!.token,
    );
    debugPrint('[Nakama] socket created: $_socket');
    return _socket!;
  }

  /// NEW — reconnects if socket is null (e.g. dropped between auth and game load).
  /// Called in MultiplayerMatchWorld.onLoad() before subscribing to onMatchData.
  Future<void> ensureConnected() async {
    if (_socket != null) {
      debugPrint('[Nakama] ensureConnected: socket already set');
      return;
    }
    debugPrint('[Nakama] ensureConnected: socket is NULL — reconnecting');
    await connectSocket();
    debugPrint('[Nakama] ensureConnected: reconnected → $_socket');
  }

  /// Safe socket access — throws StateError (not AssertionError).
  /// AssertionErrors are silently caught by _send's try-catch, hiding failures.
  /// StateError is a real error that surfaces clearly in the debug output.
  NakamaWebsocketClient get socket {
    if (_socket == null) {
      debugPrint('[Nakama] socket getter: _socket IS NULL!');
      throw StateError(
        'Socket not connected — call connectSocket() or ensureConnected() first',
      );
    }
    return _socket!;
  }

  // ── Matchmaking ─────────────────────────────────────────────────────────────
  Future<MatchmakerTicket> joinMatchmaker() async {
    return socket.addMatchmaker(minCount: 2, maxCount: 2, query: '*');
  }

  Future<void> cancelMatchmaker(String ticket) async {
    await socket.removeMatchmaker(ticket);
  }

  // ── Match ────────────────────────────────────────────────────────────────────
  Future<Match> joinMatch(String matchId, {String? token}) async {
    return socket.joinMatch(matchId, token: token);
  }

  /// Leave a match cleanly — keeps the socket alive for future matches.
  Future<void> leaveMatch(String matchId) async {
    try {
      await socket.leaveMatch(matchId);
    } catch (_) {
      // Match may already be gone (opponent disconnected)
    }
  }

  Future<void> sendMatchData({
    required String matchId,
    required int opCode,
    required String data,
  }) async {
    socket.sendMatchData(
      matchId: matchId,
      opCode: opCode,
      data: data.codeUnits,
    );
  }

  Future<Account> getAccount() async {
    return _c.getAccount(_session!);
  }

  Future<void> updateDisplayName(String name) async {
    await _c.updateAccount(session: _session!, displayName: name);
  }

  // ── Leaderboard ─────────────────────────────────────────────────────────────
  Future<void> submitScore(int score) async {
    if (_session == null || score <= 0) return;
    try {
      await _c.writeLeaderboardRecord(
        session:         _session!,
        leaderboardName: 'global_high_score',
        score:           score,
      );
    } catch (e) {
      debugPrint('[Nakama] submitScore failed: $e');
    }
  }

  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 100}) async {
    if (_session == null) return [];
    try {
      final result = await _c.listLeaderboardRecords(
        session:         _session!,
        leaderboardName: 'global_high_score',
        limit:           limit,
      );

      final records = result.records ?? [];
      if (records.isEmpty) return [];

      // Leaderboard only natively ships with `username` which is randomly generated (e.g. BAHXDIDUXM).
      // To display actual player names, we must fetch the underlying User objects.
      final userIds = records.map((r) => r.ownerId).whereType<String>().toList();
      final usersRes = await _c.getUsers(session: _session!, ids: userIds);
      final userMap = { for (var u in usersRes) u.id: u };

      return records.map((r) {
        final String displayName;
        if (userMap.containsKey(r.ownerId) && userMap[r.ownerId]!.displayName != null && userMap[r.ownerId]!.displayName!.isNotEmpty) {
           displayName = userMap[r.ownerId]!.displayName!;
        } else {
           displayName = r.username ?? 'Unknown';
        }

        return LeaderboardEntry(
          rank:        int.tryParse(r.rank ?? '0') ?? 0,
          displayName: displayName,
          username:    r.username ?? '',
          score:       int.tryParse(r.score ?? '0') ?? 0,
          userId:      r.ownerId ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[Nakama] getLeaderboard failed: $e');
      return [];
    }
  }

  // ── Friends ─────────────────────────────────────────────────────────────────
  Future<void> addFriend(String userId) async {
    if (_session == null) return;
    try {
      await _c.addFriends(session: _session!, ids: [userId]);
    } catch (e) {
      debugPrint('[Nakama] addFriend failed: $e');
    }
  }

  Future<void> addFriendByUsername(String username) async {
    if (_session == null) return;
    try {
      await _c.addFriends(session: _session!, ids: [], usernames: [username]);
    } catch (e) {
      debugPrint('[Nakama] addFriendByUsername failed: $e');
      rethrow; // Let UI handle the error
    }
  }

  Future<void> acceptFriend(String userId) async {
    if (_session == null) return;
    try {
      await _c.addFriends(session: _session!, ids: [userId]);
    } catch (e) {
      debugPrint('[Nakama] acceptFriend failed: $e');
    }
  }

  Future<void> removeFriend(String userId) async {
    if (_session == null) return;
    try {
      await _c.deleteFriends(session: _session!, ids: [userId]);
    } catch (e) {
      debugPrint('[Nakama] removeFriend failed: $e');
    }
  }

  Future<List<FriendModel>> getFriends() async {
    if (_session == null) return [];
    try {
      final result = await _c.listFriends(session: _session!);
      return result.friends?.map((f) {
        final state = switch (f.state.index ?? 0) {
          0 => FriendState.mutual,
          1 => FriendState.sentByMe,
          2 => FriendState.sentByThem,
          3 => FriendState.blocked,
          _ => FriendState.mutual,
        };
        return FriendModel(
          userId:      f.user.id ?? '',
          displayName: f.user.displayName ?? f.user.username ?? 'Unknown',
          username:    f.user.username ?? '',
          friendState: state,
          online:      f.user.online ?? false,
        );
      }).toList() ?? [];
    } catch (e) {
      debugPrint('[Nakama] getFriends failed: $e');
      return [];
    }
  }

  // ── Private Matches ─────────────────────────────────────────────────────────
  Future<String> createPrivateMatch() async {
    final match = await socket.createMatch();
    return match.matchId;
  }

  Future<Match> joinPrivateMatch(String matchId) async {
    return socket.joinMatch(matchId);
  }

  // ── Full disconnect — ONLY for auth errors / app teardown ───────────────────
  // Do NOT call this when leaving a match. Call leaveMatch() instead.
  Future<void> disconnect() async {
    _socket?.close();
    _socket = null;
  }
}
