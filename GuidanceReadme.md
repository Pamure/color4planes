# color4planes — Developer Guide v5

> Attach this file to an AI assistant to give it full context about this Flutter + Nakama multiplayer game project.

---

## Project Overview

**color4planes** is a Flutter game using the Flame engine with Riverpod state management and Nakama as the backend game server (authentication, matchmaking, storage, leaderboard, friends).

- **Dev server**: 192.168.1.8 (local network, port 7350, no SSL)
- **Prod server**: api.abba-s.dev (port 443, HTTPS via Nginx)
- **Server machine**: Ubuntu box called "mark2" running Nakama + Postgres in Docker
- **Flutter run command (dev)**: `flutter run --dart-define=SERVER_KEY=yourkey`
- **Flutter build command (prod)**: `flutter build apk --dart-define=ENV=prod --dart-define=SERVER_KEY=yourkey --release`

---

## env.dart — How Dev/Prod Switching Works

```dart
class Env {
  Env._(); // private constructor

  // Reads --dart-define=ENV=prod at COMPILE TIME. Default is 'dev'.
  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static bool get isProd => _env == 'prod';

  // Dev: connect to 192.168.1.8:7350 (no SSL)
  // Prod: connect to api.abba-s.dev:443 (SSL)
  static String get nakamaHost => isProd ? 'api.abba-s.dev' : '192.168.1.8';
  static int    get nakamaPort => isProd ? 443 : 7350;
  static bool   get nakamaSSL  => isProd;

  // SERVER_KEY is also a --dart-define. Dev default is in source — that's fine.
  // Prod key must NEVER be hardcoded. Only pass via --dart-define at build time.
  static const String serverKey = String.fromEnvironment(
    'SERVER_KEY',
    defaultValue: 'mariyamisfrommuzaffarpur', // dev default only
  );
}
```

---

## Project File Structure

```
lib/
  components/
    alien_ship.dart
    bullet.dart
    bullet_trail.dart
    explosion.dart
    game_timer.dart
    jet.dart
    lane.dart
    multiplayer_bullet.dart
    opponent_bullet.dart
    opponent_plane.dart
  core/
    app_router.dart
    constants.dart
    env.dart
    responsive.dart
  main.dart
  managers/
    audio_manager.dart
    difficulty_manager.dart
    input_manager.dart
    spawn_manager.dart
  models/
    game_event.dart
    match_state.dart
    op_code.dart
    player_state.dart
    player_stats.dart
    user_model.dart
  overlays/
    game_over_overlay.dart
    hud_overlay.dart
    multiplayer_hud_overlay.dart
    multiplayer_result_overlay.dart
    pause_overlay.dart
  providers/
    auth_provider.dart
    game_provider.dart
    multiplayer_provider.dart
    settings_provider.dart
    stats_provider.dart
  screens/
    game_screen.dart
    home_screen.dart
    multiplayer_game_screen.dart
    multiplayer_lobby_screen.dart
    name_setup_screen.dart
    settings_screen.dart
    splash_screen.dart
  services/
    nakama_service.dart
  theme/
    app_theme.dart
  widgets/
    starfield_background.dart
```

---

## Architecture Overview

### State Management — Riverpod

All state is managed with Riverpod. The three things you do:

```dart
// 1. DEFINE — create a provider and its notifier
final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);

class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() => MyState(); // initial state, called once on first access

  void doSomething() {
    state = state.copyWith(value: 42); // assign to state to trigger rebuild
  }
}

// 2. WATCH — inside build(), subscribe so widget rebuilds on change
final data = ref.watch(myProvider);

// 3. READ — inside callbacks/Flame update(), just get value once (no subscription)
ref.read(myProvider.notifier).doSomething();

// LISTEN — run a callback when state changes (navigation, sound effects)
ref.listen(myProvider, (prev, next) { /* side effect */ });
```

| Method | When to Use | Rebuilds Widget? |
|---|---|---|
| `ref.watch(p)` | Inside `build()` — widget should auto-update | Yes |
| `ref.read(p)` | Inside callbacks/event handlers/Flame update() | No |
| `ref.listen(p, fn)` | Side effects when state changes: navigate, play sound | No (runs callback) |
| `ref.watch(p.select(fn))` | Watch only ONE field — widget only rebuilds for that field | Only for that field |

**Performance tip**: In HUDs, use `.select()`. E.g. `ref.watch(gameSessionProvider.select((s) => s.score))` — rebuilds ONLY when score changes.

**Why copyWith?** All state classes are immutable. Riverpod detects changes by comparing objects. If you mutated the same object it would look identical. `copyWith` creates a new object = definitely changed = rebuild fires.

### Auth Flow

`auth_provider.dart` uses a `sealed class AuthState` with three subclasses: `AuthLoading`, `AuthGuest`, `AuthAuthenticated`. The `_init()` flow:

1. Load SharedPreferences (fast, local)
2. Get or create a device UUID (the "password" for device auth)
3. Try to authenticate with Nakama → open WebSocket
4. On success → `AuthAuthenticated`
5. On failure (offline, server down) → `AuthGuest` — game still works, multiplayer/leaderboard unavailable

### NakamaService — Singleton Pattern

```dart
class NakamaService {
  NakamaService._(); // private constructor — nobody outside can call NakamaService()
  static final NakamaService instance = NakamaService._(); // ONE instance, shared everywhere
}
// Usage: NakamaService.instance.authenticate(deviceId)
```

### NakamaService Key Methods

| Method | What It Does | Returns |
|---|---|---|
| `initialize()` | Creates the HTTP client with host/port/serverKey | void |
| `authenticate(deviceId)` | Login or create account. Stores the session. | Session |
| `connectSocket()` | Opens WebSocket using the session token | WebsocketClient |
| `ensureConnected()` | Reconnects socket if null. Called before MP game starts. | void |
| `getAccount()` | HTTP call — returns full account including display name | Account |
| `updateDisplayName(name)` | HTTP call — saves new name to Nakama account | void |
| `joinMatchmaker()` | Enter the random match queue | MatchmakerTicket |
| `joinMatch(id, token)` | Join a specific match | Match |
| `sendMatchData(...)` | Send a real-time event to the other player | void |
| `leaveMatch(matchId)` | Leave cleanly — keeps socket alive for future matches | void |

### How Nakama Works

Two communication channels:

- **HTTP REST** — login, get account, update name, read/write storage, leaderboard. One request → one response → done.
- **WebSocket** — matchmaking, real-time match events (bullets, lane switches), friend presence. Always-open stream for the whole session.

**Authentication**: App calls `authenticateDevice(deviceId: uuid)`. Nakama finds or creates an account. Returns a JWT session token. App includes token in all subsequent HTTP requests and uses it to open the WebSocket. Token expires after `token_expiry_sec` in `config.yml` (CHANGE from 70 days to 7 days).

---

## Critical Bugs to Fix (v5 Audit — Fix These First)

### Bug 1 — Game State Not Reset on Restart (CRITICAL)

**File**: `lib/providers/game_provider.dart`

**Problem**: When `restartGame()` is called, the `GameSessionState` is not fully reset. Fields like `shipsDestroyed` and `score` carry over from the previous session. The game shows wrong score/kill counts after restart.

**Fix**: In `restartGame()` or wherever the game resets, call:
```dart
state = const GameSessionState(); // reset to initial state
```

### Bug 2 — BGM Stacks on Restart (CRITICAL)

**File**: `lib/managers/audio_manager.dart`

**Problem**: `playMusic()` opens a new BGM stream every time it's called without stopping the old one. After a few restarts you have multiple BGM streams playing simultaneously, dragging down FPS to 10-15fps.

**Bug code**:
```dart
Future<void> playMusic() async {
  if (!_musicOn) return;
  try {
    // If old BGM is still running, this opens a SECOND stream.
    await FlameAudio.bgm.play(AudioConfig.bgm, volume: AudioConfig.musicVol);
  } catch (e) {
    debugPrint('[Audio] playMusic failed: $e');
  }
}
```

**Fix**:
```dart
Future<void> playMusic() async {
  if (!_musicOn) return;
  try {
    // FIX: Always stop the old stream before starting a new one.
    // stopMusic() is silent if nothing is playing — completely safe to call.
    stopMusic();
    await FlameAudio.bgm.play(AudioConfig.bgm, volume: AudioConfig.musicVol);
  } catch (e) {
    debugPrint('[Audio] playMusic failed: $e');
  }
}
```

Also fix `restartGame()` in `game_screen.dart` to be explicit:
```dart
void restartGame() {
  // ... cleanup code ...
  audioManager.stopMusic();   // Stop first (redundant but explicit)
  audioManager.playMusic();   // playMusic() now also stops internally
}
```

### Bug 3 — BGM Starts Playing on the Settings Screen (MEDIUM)

**File**: `lib/providers/settings_provider.dart`

**Problem**: When user flips music ON in Settings, `toggleMusic()` calls `FlameAudio.bgm.play()` unconditionally — even if they're on the Settings screen between games. Music should only start when a game starts.

**Fix**: When turning music ON, don't start playing. Only stop when turning OFF:
```dart
Future<void> toggleMusic() async {
  final newVal = !state.musicEnabled;
  state = state.copyWith(musicEnabled: newVal);
  await _prefs.setBool(StorageKeys.musicEnabled, newVal);

  if (!newVal) {
    // Turning OFF: stop any currently-playing BGM immediately
    try { FlameAudio.bgm.stop(); } catch (_) {}
  }
  // Turning ON: do NOT start music here.
  // AudioManager.playMusic() is called when a game starts.
  // It reads _musicOn from SharedPreferences on initialize().
}
```

### Bug 4 — BGM Keeps Playing After Pause → Main Menu (MEDIUM)

**File**: `lib/screens/game_screen.dart`

**Problem**: When player pauses and taps "Main Menu", `_mainMenu()` navigates to home but never calls `stopMusic()`. BGM from the game keeps playing on the Home screen.

**Fix**:
```dart
void _mainMenu() {
  _game.audio?.stopMusic();   // Stop BGM before leaving the game screen
  _game.resumeEngine();
  context.go(RoutePaths.home);
}
```

Note: Use `_game.audio?.stopMusic()` not `audioManager.stopMusic()` — `_game.audio` is a null-safe getter to the AudioManager from the Flame component tree.

### Bug 5 — Bullets Pass Through Aliens at Low FPS / Tunneling (CRITICAL)

**Files**: `lib/components/bullet.dart`, `lib/components/alien_ship.dart`, `lib/components/opponent_bullet.dart`, `lib/components/multiplayer_bullet.dart`

**Problem**: Flame's collision detection is discrete — it checks overlap at each frame, not the path traveled. At 60fps, bullet moves 7.2px per frame (fine). At 10fps (when audio stacks from Bug 2), bullet moves 45px per frame — it can jump completely past an alien without overlapping.

**Math**: Bullet speed = 450px/s. Alien height = 48px. Tunneling starts below 9 FPS (`dt_max = 48/450 = 0.107s`).

**Fix**: Cap `dt` to 0.05s max (equivalent to 20fps minimum physics step):

```dart
// bullet.dart update()
@override
void update(double dt) {
  super.update(dt);
  if (_hasCollided) return;
  final safeDt = dt.clamp(0.0, 0.05); // Cap dt — prevents tunneling at low FPS
  position.y -= _speed * safeDt;
  if (position.y < -_height) removeFromParent();
}

// alien_ship.dart update()
@override
void update(double dt) {
  super.update(dt);
  if (isDestroyed) return;
  final safeDt = dt.clamp(0.0, 0.05); // Same cap for aliens
  position.y += speed * safeDt;
  if (position.y + size.y / 2 >= game.size.y) {
    if (game.ref.read(gameSessionProvider).status == GameStatus.playing) {
      game.mainView?.onGameOver();
    }
    removeFromParent();
  }
}
```

Apply the same `dt.clamp(0.0, 0.05)` to `OpponentBullet.update()` and `MultiplayerPlayerBullet.update()`.

### Bug 6 — `_hasCollided` Flag Set Before Status Check (MEDIUM)

**File**: `lib/components/bullet.dart`

**Problem**: In `onCollisionStart()`, the old order was: (1) check if already collided, (2) check if it's an alien ship, (3) **set `_hasCollided = true`**, (4) check if game is playing. If a collision happens during a state transition (not "playing"), the bullet gets permanently used up without doing anything.

**Fix**: Move the status check BEFORE setting `_hasCollided`:
```dart
@override
void onCollisionStart(Set<Vector2> points, PositionComponent other) {
  super.onCollisionStart(points, other);
  if (_hasCollided) return;
  if (other is! AlienShip || other.isDestroyed) return;
  // FIX: Check status BEFORE setting _hasCollided
  if (game.ref.read(gameSessionProvider).status != GameStatus.playing) return;
  _hasCollided = true; // Only mark used if all checks pass

  if (color == other.shipColor) {
    other.destroy();
    removeFromParent();
    game.mainView?.onShipDestroyedAt(other.position, other.shipColor, GameConfig.basePointsPerKill);
  } else {
    game.mainView?.onGameOver();
  }
}
```

### Bug 7 — SpawnManager Count Never Decrements When Alien Escapes (MEDIUM)

**Files**: `lib/components/alien_ship.dart`, `lib/managers/spawn_manager.dart`

**Problem**: `SpawnManager.currentCount` is only decremented in `onShipDestroyed()`, which is only called when a bullet hits an alien. But aliens can also leave the screen by reaching the bottom or colliding with a player plane — neither of these decrements `currentCount`. After many escapes, the count thinks 15 ships are alive when there are 0, and no new ships spawn.

**Fix**: Call `spawnManager.onShipDestroyed()` in BOTH exit paths:
```dart
// alien_ship.dart update() — when alien reaches bottom
if (position.y + size.y / 2 >= game.size.y) {
  if (game.ref.read(gameSessionProvider).status == GameStatus.playing) {
    game.mainView?.onGameOver();
  }
  game.mainView?.spawnManager.onShipDestroyed(); // FIX: decrement count
  isDestroyed = true; // prevent double-decrement
  removeFromParent();
}

// alien_ship.dart onCollisionStart() — when alien hits player plane
@override
void onCollisionStart(Set<Vector2> points, PositionComponent other) {
  super.onCollisionStart(points, other);
  if (isDestroyed || other is! PlayerPlane) return;
  if (game.ref.read(gameSessionProvider).status != GameStatus.playing) return;
  game.mainView?.spawnManager.onShipDestroyed(); // FIX: decrement count
  isDestroyed = true;
  game.mainView?.onGameOver();
}
```

Note: `spawnManager` in `MainView` must NOT start with underscore (it doesn't — `late SpawnManager spawnManager`) so it's already accessible as `game.mainView?.spawnManager`.

---

## Bug Fix Summary Table

| Bug | File | What to Change | Impact |
|---|---|---|---|
| 1 | game_provider.dart | Reset full GameSessionState on restart | CRITICAL — wrong score/kills after restart |
| 2 | audio_manager.dart | Call stopMusic() before every playMusic() | CRITICAL — stacked audio kills FPS → causes Bug 5 |
| 3 | settings_provider.dart | Don't play BGM when toggling music ON from Settings | MEDIUM — weird audio on non-game screens |
| 4 | game_screen.dart | Call stopMusic() in _mainMenu() | MEDIUM — BGM plays on home screen |
| 5 | bullet.dart, alien_ship.dart, opponent_bullet.dart, multiplayer_bullet.dart | Add `dt.clamp(0.0, 0.05)` | CRITICAL — bullets pass through aliens at low FPS |
| 6 | bullet.dart | Move status check before `_hasCollided = true` | MEDIUM — bullets wasted during state transitions |
| 7 | alien_ship.dart | Call spawnManager.onShipDestroyed() when alien escapes | MEDIUM — spawn cap gets stuck, no new enemies |

---

## Features to Implement (In Order)

### Feature 1 — Name Setup Screen (HIGH PRIORITY)

**Goal**: On first launch, ask the player to pick a display name. Save to Nakama. Never show a UUID as a username again.

**How it works**:
1. App starts → SplashScreen → auth loads → `AuthNotifier._init()` runs
2. SplashScreen checks if display name is still the default "Pilot"
3. If name not set → navigate to `/setup-name`. If name set → go to `/home`
4. User types name → tap CONFIRM → saves to Nakama → goes to `/home`

**Step 1** — Add to `constants.dart`:
```dart
static const String nameSetup = '/setup-name';
```

**Step 2** — Add route to `app_router.dart`:
```dart
import 'package:color4planes/screens/name_setup_screen.dart';

// In routes list:
GoRoute(
  path: RoutePaths.nameSetup,
  builder: (context, state) => const NameSetupScreen(),
),
```

**Step 3** — Update `splash_screen.dart` `_tryNavigate()`:
```dart
void _tryNavigate(AuthState authState) {
  if (_navigated) return;
  _navigated = true;
  Future.delayed(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    final hasName = authState.when(
      loading: () => true,
      guest:   (u) => u.displayName != 'Pilot',
      authenticated: (u) => u.displayName != 'Pilot',
    );
    if (hasName) {
      context.go(RoutePaths.home);
    } else {
      context.go(RoutePaths.nameSetup); // first launch
    }
  });
}
```

**Step 4** — Create `lib/screens/name_setup_screen.dart`:

A `ConsumerStatefulWidget` with a `TextFormField` for name input (validate 2-20 chars), a CONFIRM button that calls `ref.read(authProvider.notifier).setDisplayName(name)`, shows loading state, then navigates to `/home`.

**Step 5** — Add `setDisplayName()` to `auth_provider.dart`:
```dart
Future<void> setDisplayName(String name) async {
  await NakamaService.instance.updateDisplayName(name);
  // Update local state with new display name
  state = state.when(
    loading: (_) => state,
    guest: (u) => AuthGuest(u.copyWith(displayName: name)),
    authenticated: (u) => AuthAuthenticated(u.copyWith(displayName: name)),
  );
}
```

---

### Feature 2 — Player Stats + Cloud Save (HIGH PRIORITY)

**Goal**: Track games played, kills, wins, losses, best score, time played, shots fired. Save to Nakama cloud storage so data survives reinstalls.

**Step 1** — Create `lib/models/player_stats.dart`:
```dart
class PlayerStats {
  final int totalGamesPlayed;
  final int totalKills;
  final int totalWins;
  final int totalLosses;
  final int bestScore;
  final int totalSecondsPlayed;
  final int totalShotsFired;

  const PlayerStats({
    this.totalGamesPlayed = 0, this.totalKills = 0, this.totalWins = 0,
    this.totalLosses = 0, this.bestScore = 0, this.totalSecondsPlayed = 0,
    this.totalShotsFired = 0,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
    totalGamesPlayed:   json['totalGamesPlayed']   as int? ?? 0,
    totalKills:         json['totalKills']          as int? ?? 0,
    totalWins:          json['totalWins']           as int? ?? 0,
    totalLosses:        json['totalLosses']         as int? ?? 0,
    bestScore:          json['bestScore']           as int? ?? 0,
    totalSecondsPlayed: json['totalSecondsPlayed']  as int? ?? 0,
    totalShotsFired:    json['totalShotsFired']     as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'totalGamesPlayed':   totalGamesPlayed,
    'totalKills':         totalKills,
    'totalWins':          totalWins,
    'totalLosses':        totalLosses,
    'bestScore':          bestScore,
    'totalSecondsPlayed': totalSecondsPlayed,
    'totalShotsFired':    totalShotsFired,
  };

  PlayerStats copyWith({...}) => PlayerStats(...);
}
```

**Step 2** — Add storage methods to `nakama_service.dart`:
```dart
import 'dart:convert';
import 'package:color4planes/models/player_stats.dart';

static const String _statsCollection = 'player_stats';
static const String _statsKey        = 'stats';

Future<void> saveStats(PlayerStats stats) async {
  if (_session == null) return;
  await _c.writeStorageObjects(
    session: _session!,
    objects: [
      StorageObjectWrite(
        collection:      _statsCollection,
        key:             _statsKey,
        value:           jsonEncode(stats.toJson()),
        permissionRead:  2, // public read
        permissionWrite: 1, // owner only
      ),
    ],
  );
}

Future<PlayerStats> loadStats() async {
  if (_session == null) return const PlayerStats();
  final result = await _c.readStorageObjects(
    session: _session!,
    objectIds: [StorageObjectId(collection: _statsCollection, key: _statsKey, userId: _session!.userId)],
  );
  if (result.objects.isEmpty) return const PlayerStats();
  try {
    final json = jsonDecode(result.objects.first.value) as Map<String, dynamic>;
    return PlayerStats.fromJson(json);
  } catch (_) {
    return const PlayerStats(); // corrupt data → return empty
  }
}
```

**Step 3** — Create `lib/providers/stats_provider.dart`:
```dart
class StatsNotifier extends AsyncNotifier<PlayerStats> {
  @override
  Future<PlayerStats> build() async {
    return NakamaService.instance.loadStats(); // loads from server on first access
  }

  Future<void> recordSoloGame({
    required int kills, required int score,
    required int secondsPlayed, required int shotsFired,
  }) async {
    final current = state.valueOrNull ?? const PlayerStats();
    final updated = current.copyWith(
      totalGamesPlayed:   current.totalGamesPlayed + 1,
      totalKills:         current.totalKills + kills,
      bestScore:          score > current.bestScore ? score : current.bestScore,
      totalSecondsPlayed: current.totalSecondsPlayed + secondsPlayed,
      totalShotsFired:    current.totalShotsFired + shotsFired,
    );
    state = AsyncValue.data(updated); // update local state immediately
    await NakamaService.instance.saveStats(updated); // then sync to server
  }

  Future<void> recordMultiplayerGame({required bool won}) async {
    final current = state.valueOrNull ?? const PlayerStats();
    final updated = current.copyWith(
      totalGamesPlayed: current.totalGamesPlayed + 1,
      totalWins:        won ? current.totalWins + 1 : current.totalWins,
      totalLosses:      won ? current.totalLosses : current.totalLosses + 1,
    );
    state = AsyncValue.data(updated);
    await NakamaService.instance.saveStats(updated);
  }
}

final statsProvider = AsyncNotifierProvider<StatsNotifier, PlayerStats>(StatsNotifier.new);
```

**Step 4** — Hook into `game_provider.dart` — call in `triggerGameOver()`:
```dart
void triggerGameOver({required String survivedFor, required int shotsFired, required double secondsPlayed}) {
  if (state.status == GameStatus.gameOver) return;
  state = state.copyWith(status: GameStatus.gameOver, finalTime: survivedFor, totalShots: shotsFired);

  // Update stats — runs in background, doesn't block UI
  ref.read(statsProvider.notifier).recordSoloGame(
    kills:         state.shipsDestroyed,
    score:         state.score,
    secondsPlayed: secondsPlayed.toInt(),
    shotsFired:    shotsFired,
  );
}
```

---

### Feature 3 — Leaderboard (MEDIUM PRIORITY)

**Goal**: Global top scores using Nakama's built-in leaderboard API. Auto-submit after every solo game.

**How Nakama leaderboards work**:
- Submit: `writeLeaderboardRecord(leaderboardId: 'high_score', score: yourScore)`. Nakama auto-keeps only the best score per player.
- Read: `listLeaderboardRecords(leaderboardId: 'high_score', limit: 100)`. Returns ranked list with rank, display name, score, user ID.
- The leaderboard with ID `'high_score'` is auto-created on first submit.

**Add to `nakama_service.dart`**:
```dart
import 'package:color4planes/models/leaderboard_entry.dart';

Future<void> submitScore(int score) async {
  if (_session == null || score <= 0) return;
  try {
    await _c.writeLeaderboardRecord(
      session:       _session!,
      leaderboardId: 'high_score',
      score:         score,
      metadata:      '{}',
    );
  } catch (e) {
    debugPrint('[Nakama] submitScore failed: $e');
  }
}

Future<List<LeaderboardEntry>> getLeaderboard({int limit = 100}) async {
  if (_session == null) return [];
  try {
    final result = await _c.listLeaderboardRecords(
      session:       _session!,
      leaderboardId: 'high_score',
      limit:         limit,
    );
    return result.records.map((r) => LeaderboardEntry(
      rank:        r.rank.toInt(),
      displayName: r.username,
      score:       r.score.toInt(),
      userId:      r.ownerId,
    )).toList();
  } catch (e) {
    debugPrint('[Nakama] getLeaderboard failed: $e');
    return [];
  }
}
```

**Create `lib/models/leaderboard_entry.dart`**:
```dart
class LeaderboardEntry {
  final int    rank;
  final String displayName;
  final int    score;
  final String userId;
  const LeaderboardEntry({required this.rank, required this.displayName, required this.score, required this.userId});
}
```

**Create `lib/screens/leaderboard_screen.dart`** — a `ConsumerWidget` that uses a `FutureProvider` to load and display the leaderboard in a scrollable list.

**Also hook `submitScore` into `game_provider.dart` `triggerGameOver()`** (alongside stats recording):
```dart
ref.read(statsProvider.notifier).recordSoloGame(...);
NakamaService.instance.submitScore(state.score); // non-blocking
```

---

### Feature 4 — Friends System (MEDIUM PRIORITY)

**Goal**: Add friends by sharing User IDs. See friend list with online/offline status. Accept incoming requests.

**Add to `nakama_service.dart`**:
```dart
Future<void>          addFriend(String userId)    async => _c.addFriends(session: _session!, ids: [userId]);
Future<void>          acceptFriend(String userId)  async => _c.addFriends(session: _session!, ids: [userId]);
Future<void>          removeFriend(String userId)  async => _c.deleteFriends(session: _session!, ids: [userId]);
Future<List<Friend>>  getFriends()                 async {
  final res = await _c.listFriends(session: _session!);
  return res.friends;
}
```

**Create `lib/models/friend_model.dart`**:
```dart
enum FriendState { mutual, sentByMe, sentByThem, blocked }

class FriendModel {
  final String      userId;
  final String      displayName;
  final FriendState state;
  final bool        online;
  const FriendModel({required this.userId, required this.displayName, required this.state, required this.online});
}
```

**Create `lib/screens/friends_screen.dart`** with:
- Display "Your Pilot ID" (their own user ID they can copy to share)
- Text field to paste a friend's Pilot ID + ADD button
- Friend list showing each friend with online dot, name, state label (ONLINE / OFFLINE / PENDING / WANTS TO ADD YOU)
- ACCEPT button for incoming requests
- X button to remove friend

---

### Feature 5 — Private Matches / Play With Friends (MEDIUM PRIORITY)

**Goal**: Create a private match, share a code, friend joins directly. Bypasses random matchmaker.

**How it works**:
- Host: calls `socket.createMatch()` → gets a `matchId`. Shows first 8 chars as a "room code."
- Guest: pastes the full match ID → calls `socket.joinMatch(matchId)` directly (no matchmaker token needed).
- Both use the same `onMatchData` stream and `sendMatchData` system already in place.

**Add to `nakama_service.dart`**:
```dart
/// Creates a new private match. Returns the match ID.
Future<String> createPrivateMatch() async {
  final match = await socket.createMatch();
  return match.matchId;
}

/// Joins a private match directly by its full ID.
Future<Match> joinPrivateMatch(String matchId) async {
  return socket.joinMatch(matchId); // joinMatch without a token = join by ID directly
}
```

**Update `multiplayer_lobby_screen.dart`** to add a "PLAY WITH FRIEND" section below the existing FIND MATCH button with CREATE PRIVATE MATCH and JOIN PRIVATE MATCH (with text input for match ID) options.

**Update `multiplayer_provider.dart`** to add `joinPrivateMatch(String matchId)` method that calls `NakamaService.instance.joinPrivateMatch(matchId)` and transitions to the game screen.

---

### Feature 6 — Profile Screen (MEDIUM PRIORITY)

**Goal**: A "Pilot Dossier" screen showing all player stats — games played, kills, wins/losses, win rate, best score, hours played, shots fired.

**Create `lib/screens/profile_screen.dart`** — a `ConsumerWidget` that reads `statsProvider` and displays stats in a themed layout matching the game aesthetic (dark background, monospace font, space colors).

---

### Feature 7 — Google Sign-In (DO LAST — After Everything Else Works)

dont implement this hii antigravity claude we will do this inn future in 2027 dont do this right now skip the google implementaiotn

**Goal**: Cross-device accounts, proper identity. Required for Play Store.

**Why last**: Requires Google Developer Console setup, SHA-1 fingerprints for Android, and App Store configuration for iOS. Device auth (UUID) works well for closed friend groups. Add Google Sign-In when player count grows and people ask for cross-device support.




```

---

## Routes to Add to app_router.dart / constants.dart

```dart
// In RoutePaths class (constants.dart):
static const String nameSetup   = '/setup-name';
static const String leaderboard = '/leaderboard';
static const String friends     = '/friends';
static const String profile     = '/profile';

// In appRouterProvider routes list (app_router.dart):
GoRoute(path: RoutePaths.nameSetup,   builder: (c, s) => const NameSetupScreen()),
GoRoute(path: RoutePaths.leaderboard, builder: (c, s) => const LeaderboardScreen()),
GoRoute(path: RoutePaths.friends,     builder: (c, s) => const FriendsScreen()),
GoRoute(path: RoutePaths.profile,     builder: (c, s) => const ProfileScreen()),
```

---

## Files to Create (New)

| File | What It Does | Priority |
|---|---|---|
| `lib/screens/name_setup_screen.dart` | First-launch name picker | HIGH |
| `lib/models/player_stats.dart` | Stats data class with toJson/fromJson | HIGH |
| `lib/providers/stats_provider.dart` | AsyncNotifier that loads/saves stats | HIGH |
| `lib/models/leaderboard_entry.dart` | Simple data class for leaderboard rows | MEDIUM |
| `lib/screens/leaderboard_screen.dart` | Top scores display | MEDIUM |
| `lib/models/friend_model.dart` | FriendState enum + FriendModel | MEDIUM |
| `lib/screens/friends_screen.dart` | Add friends, view list, accept requests | MEDIUM |
| `lib/screens/profile_screen.dart` | Pilot dossier with all stats | MEDIUM |

---

## Files to Edit

| File | What to Add |
|---|---|
| `lib/core/constants.dart` | Add `RoutePaths.nameSetup`, `.leaderboard`, `.friends`, `.profile` |
| `lib/core/app_router.dart` | Add routes for all new screens |
| `lib/screens/splash_screen.dart` | Update `_tryNavigate()` to check if name is set |
| `lib/providers/auth_provider.dart` | Add `setDisplayName()` method |
| `lib/services/nakama_service.dart` | Add `saveStats`, `loadStats`, `submitScore`, `getLeaderboard`, `addFriend`, `getFriends`, `acceptFriend`, `removeFriend`, `createPrivateMatch`, `joinPrivateMatch` |
| `lib/providers/game_provider.dart` | Hook `recordSoloGame` + `submitScore` into `triggerGameOver` |
| `lib/providers/multiplayer_provider.dart` | Add `joinPrivateMatch` + hook `recordMultiplayerGame` into `_endGame` |
| `lib/screens/home_screen.dart` | Add LEADERBOARD + PROFILE + FRIENDS buttons |

---

## Server Setup — Nginx + SSL (Production)

Your Nakama runs on mark2 (192.168.1.8), Docker-bound to 127.0.0.1. Nginx proxies HTTPS from the outside world to it. Domain: `api.abba-s.dev`.

```bash
# 1. Install Nginx and Certbot
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx -y

# 2. Create the Nakama proxy config
sudo nano /etc/nginx/sites-available/nakama
```

Paste this content:
```nginx
server {
    listen 80;
    server_name api.abba-s.dev;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.abba-s.dev;

    # SSL managed by certbot

    location / {
        proxy_pass         http://127.0.0.1:7350;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";   # required for WebSocket
        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_read_timeout 3600;  # keep WebSocket connections alive
    }
}
```

```bash
# 3. Enable the site
sudo ln -s /etc/nginx/sites-available/nakama /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 4. Get SSL certificate (domain must point to your IP first)
sudo certbot --nginx -d api.abba-s.dev

# 5. Test auto-renewal
sudo certbot renew --dry-run
sudo systemctl reload nginx
```

**Note**: Your server is behind a home router. Forward ports 80 and 443 to 192.168.1.8 in your router settings. Ensure a static public IP or use dynamic DNS.

---

## Security Hardening

| Item | Status | Action Required |
|---|---|---|
| Console address | FIX NOW | Change `console.address: "0.0.0.0"` → `"127.0.0.1"` in config.yml |
| Console password | FIX NOW | Change from default to something 20+ chars random |
| Signing key | FIX NOW | Change `console.signing_key` to random 32+ chars |
| Session expiry | CHANGE | Change `token_expiry_sec: 6048000` (70 days) → `604800` (7 days) |
| Postgres exposure | GOOD | Uses `expose` not `ports` — only reachable inside Docker network |
| HTTPS/SSL | TODO | Set up Nginx + certbot as above |
| Server key in code | NOTE | Dev default is fine for dev. Never ship prod key in source. |
| Backups | TODO | Set up daily backup cron (see below) |
| SSH key auth | TODO | Disable password SSH login — use SSH keys only |
| Healthchecks | GOOD | Both postgres and nakama have health checks in docker-compose |
| Restart policy | GOOD | `restart: unless-stopped` — survives reboots |

### Fix config.yml Now

```bash
# On mark2:
sudo nano /opt/nakama/config/config.yml

# CHANGE console section to:
console:
  port: 7360
  address: "127.0.0.1"    # was "0.0.0.0" — this locks it to local only
  username: "YourUsername"
  password: "CHANGE_TO_SOMETHING_RANDOM_AND_LONG"
  signing_key: "CHANGE_THIS_TO_RANDOM_32_CHARS_MIN"

# Also change session expiry:
session:
  token_expiry_sec: 604800    # 7 days (was 6048000 = 70 days)

# Restart Nakama to apply:
cd /opt/nakama
docker compose restart nakama
```

### Automated Postgres Backups

```bash
# Create backup script
cat > /opt/nakama/backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec nakama_postgres pg_dump -U nakama nakama \
  | gzip > /opt/nakama/backups/nakama_$DATE.sql.gz
# Keep only last 7 backups
ls -t /opt/nakama/backups/nakama_*.sql.gz | tail -n +8 | xargs -r rm
echo "Backup done: nakama_$DATE.sql.gz"
EOF

chmod +x /opt/nakama/backup.sh

# Schedule daily at 3am
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/nakama/backup.sh") | crontab -

# Test it
/opt/nakama/backup.sh
```

---

## Production Build Commands

```bash
# Android release APK
flutter build apk \
  --dart-define=ENV=prod \
  --dart-define=SERVER_KEY=your-actual-server-key \
  --release

# Android App Bundle (for Play Store)
flutter build appbundle \
  --dart-define=ENV=prod \
  --dart-define=SERVER_KEY=your-actual-server-key \
  --release

# iOS
flutter build ipa \
  --dart-define=ENV=prod \
  --dart-define=SERVER_KEY=your-actual-server-key \
  --release
```

**IMPORTANT**: Never commit the production server key. The dev default `mariyamisfrommuzaffarpur` in source code is fine for dev. The production key must ONLY be passed via `--dart-define=SERVER_KEY=...` at build time. The key is compiled into the binary (not completely secure, but much better than plain text in a public repo).

---

## Verify Server After Deploy

```bash
# Check containers are running
docker ps

# Watch Nakama logs live
docker logs nakama_server -f --tail 50

# Test API is responding
curl -s http://localhost:7350/healthcheck
# Should return: {}

# From outside (after SSL):
curl -s https://api.abba-s.dev/healthcheck
# Should return: {}

# Check disk space
df -h /opt/nakama
```

---

## Implementation Order (What to Do This Week)

**Immediate (Critical Fixes)**:
1. Fix config.yml: console address → 127.0.0.1, change passwords, fix session expiry
2. Apply all 7 bug fixes above — especially Bug 1, 2, and 5
3. Run `flutter analyze`, fix all warnings

**Next (Core Social Features)**:
1. Feature 1: NameSetupScreen + setDisplayName()
2. Feature 2: PlayerStats model + StatsProvider + saveStats()
3. Feature 3: Leaderboard screen + submitScore()

**After That (Friends)**:
1. Feature 4: FriendsScreen + friend methods in NakamaService
2. Feature 5: Private matches + joinPrivateMatch()
3. Feature 6: Profile screen

**Server + Polish**:
1. Nginx + SSL setup
2. Backup cron job
3. SSH key-only auth
4. Google Sign-In (when player base is large enough)

---

*color4planes — developer guide v5 · 7 critical bugs fixed · dt clamping · audio stack fix · correct restart order*