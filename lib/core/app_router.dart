// lib/core/app_router.dart
//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:color4planes/core/constants.dart';
import 'package:color4planes/models/match_state.dart';
import 'package:color4planes/providers/multiplayer_provider.dart';
import 'package:color4planes/screens/game_screen.dart';
import 'package:color4planes/screens/home_screen.dart';
import 'package:color4planes/screens/multiplayer_game_screen.dart';
import 'package:color4planes/screens/multiplayer_lobby_screen.dart';
import 'package:color4planes/screens/settings_screen.dart';
import 'package:color4planes/screens/splash_screen.dart';
import 'package:color4planes/screens/name_setup_screen.dart';
import 'package:color4planes/screens/leaderboard_screen.dart';
import 'package:color4planes/screens/friends_screen.dart';
import 'package:color4planes/screens/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    errorBuilder: (context, state) => const HomeScreen(),
    redirect: (context, routerState) {
      if (routerState.uri.path == RoutePaths.multiplayerGame) {
        final container = ProviderScope.containerOf(context, listen: false);
        final mpState = container.read(multiplayerProvider);

        final isActive =
            mpState.status == MatchStatus.found ||
            mpState.status == MatchStatus.countdown ||
            mpState.status == MatchStatus.playing ||
            mpState.status == MatchStatus.finished;

        if (!isActive) return RoutePaths.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.nameSetup,
        builder: (context, state) => const NameSetupScreen(),
      ),
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.game,
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: RoutePaths.multiplayer,
        builder: (context, state) => const MultiplayerLobbyScreen(),
      ),
      GoRoute(
        path: RoutePaths.multiplayerGame,
        builder: (context, state) => const MultiplayerGameScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: RoutePaths.friends,
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

// Backward-compat non-provider router (kept for main.dart if needed)
final appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  errorBuilder: (context, state) => const HomeScreen(),
  routes: [
    GoRoute(path: RoutePaths.splash, builder: (c, s) => const SplashScreen()),
    GoRoute(path: RoutePaths.home, builder: (c, s) => const HomeScreen()),
    GoRoute(path: RoutePaths.game, builder: (c, s) => const GameScreen()),
    GoRoute(
      path: RoutePaths.multiplayer,
      builder: (c, s) => const MultiplayerLobbyScreen(),
    ),
    GoRoute(
      path: RoutePaths.multiplayerGame,
      builder: (c, s) => const MultiplayerGameScreen(),
    ),
    GoRoute(
      path: RoutePaths.settings,
      builder: (c, s) => const SettingsScreen(),
    ),
    GoRoute(
      path: RoutePaths.leaderboard,
      builder: (c, s) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: RoutePaths.friends,
      builder: (c, s) => const FriendsScreen(),
    ),
    GoRoute(
      path: RoutePaths.profile,
      builder: (c, s) => const ProfileScreen(),
    ),
  ],
);
