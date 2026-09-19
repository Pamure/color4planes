// lib/providers/auth_provider.dart
//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/user_model.dart';
import 'package:color4planes/services/nakama_service.dart';

// ── Auth State ─────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthGuest extends AuthState {
  final UserModel user;
  const AuthGuest(this.user);
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
}

extension AuthStateX on AuthState {
  T when<T>({
    required T Function()           loading,
    required T Function(UserModel u) guest,
    required T Function(UserModel u) authenticated,
  }) =>
      switch (this) {
        AuthLoading()                   => loading(),
        AuthGuest(user: final u)        => guest(u),
        AuthAuthenticated(user: final u) => authenticated(u),
      };
}

// ── Auth Notifier ──────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  late SharedPreferences _prefs;
  static const _uuid = Uuid();
static String? lastError;

  @override
  AuthState build() {
    Future.microtask(() => _init());
    return const AuthLoading();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    String? storedId   = _prefs.getString(StorageKeys.guestUserId);
    String? storedName = _prefs.getString(StorageKeys.displayName);
    final  highScore   = _prefs.getInt(StorageKeys.highScore) ?? 0;

    if (storedId == null) {
      storedId = _uuid.v4();
      await _prefs.setString(StorageKeys.guestUserId, storedId);
    }

    // Try Nakama auth
    try {
      NakamaService.instance.initialize();
      await NakamaService.instance.authenticate(storedId);
      await NakamaService.instance.connectSocket();
      final account    = await NakamaService.instance.getAccount();
      final nakamaName = account.user.displayName;

      state = AuthAuthenticated(
        UserModel(
          id:          account.user.id,
          displayName: (nakamaName != null && nakamaName.isNotEmpty)
              ? nakamaName
              : (storedName ?? 'notallowedname'),
          username:    account.user.username ?? '',
          highScore: highScore,
        ),
      );

      debugPrint('[Auth] Nakama auth succeeded: ${account.user.id}');
      return;
    } catch (e) {
       AuthNotifier.lastError = e.toString(); // ← ADD THIS
      debugPrint('[Auth] Nakama unavailable, guest mode: $e');
    }

    // Guest fallback
    state = AuthGuest(
      UserModel(
        id:          storedId,
        displayName: storedName ?? 'notallowedname',
        highScore:   highScore,
      ),
    );
  }
/// Called from NameSetupScreen and Settings screen.
/// Saves to Nakama (if authenticated) AND to SharedPreferences (for offline).
Future<void> setDisplayName(String name) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return;

  // Save locally first (always works, even offline)
  await _prefs.setString(StorageKeys.displayName, trimmed);

  // Save to Nakama if we have a real connection
  if (NakamaService.instance.isReady) {
    try {
      await NakamaService.instance.updateDisplayName(trimmed);
    } catch (e) {
      debugPrint('[Auth] Could not update name on server: $e');
      // Local save succeeded — user can still proceed
    }
  }

  // Update the in-memory state so all watching widgets rebuild
  final user = _user;
  if (user == null) return;
  final updated = user.copyWith(displayName: trimmed);
  state = switch (state) {
    AuthGuest()         => AuthGuest(updated),
    AuthAuthenticated() => AuthAuthenticated(updated),
    AuthLoading()      => state,
  };
}
  Future<void> updateHighScore(int newScore) async {
    final user = _user;
    if (user == null || newScore <= user.highScore) return;

    await _prefs.setInt(StorageKeys.highScore, newScore);

    final updated = user.copyWith(highScore: newScore);
    state = switch (state) {
      AuthGuest()        => AuthGuest(updated),
      AuthAuthenticated() => AuthAuthenticated(updated),
      AuthLoading()      => state,
    };
  }

  UserModel? get _user => switch (state) {
    AuthGuest(user: final u)        => u,
    AuthAuthenticated(user: final u) => u,
    AuthLoading()                   => null,
  };
}

// ── Providers ──────────────────────────────────────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<UserModel?>(
  (ref) => ref
      .watch(authProvider)
      .when(loading: () => null, guest: (u) => u, authenticated: (u) => u),
);
