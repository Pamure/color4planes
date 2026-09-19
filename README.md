# Color4Planes

An arcade plane shooter built with **Flutter + Flame**, featuring a single-player
mode and **real-time online multiplayer** powered by **Nakama** (authentication,
matchmaking, storage, leaderboards, friends).

> Repository contains **source code and game assets only** — build output,
> dependencies, IDE files and local screen recordings are excluded via `.gitignore`.

---

## Features

- **Single-player arcade mode** — dodge meteors, shoot alien ships, escalating difficulty.
- **Online multiplayer** — matchmaking, live match state (bullets, lane switches, opponent plane), win/lose results.
- **Leaderboard** — global scores from the Nakama backend.
- **Friends** — add/see friends via Nakama presence.
- **Player profile** — display name, stats, persistent local storage.
- **Settings** — audio/music toggles and gameplay options.
- **Polished presentation** — starfield parallax background, custom HUD, pause/game-over overlays, animated jet and explosions.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart SDK `^3.11.0`) |
| Game engine | [Flame](https://flame-engine.org) `^1.35.1` |
| Audio | `flame_audio` `^2.11.14` |
| State management | `flutter_riverpod` `^3.2.1` |
| Navigation | `go_router` `^17.1.0` |
| Backend / multiplayer | [Nakama](https://heroiclabs.com/nakama/) `^1.3.0` |
| Local storage | `shared_preferences` `^2.5.4` |
| Utilities | `uuid`, `rxdart`, `google_fonts` |

---

## Project Structure

```
lib/
  main.dart                 # Entry point: providers + router + theme
  components/               # Flame game entities (jet, bullet, alien_ship, explosion, meteors, lanes)
  core/                     # app_router, constants, env, responsive helpers
  managers/                 # audio, difficulty, input, spawn managers
  models/                   # game events, match/player state, op codes
  overlays/                 # HUD, pause, game-over, multiplayer result overlays
  providers/                # Riverpod providers (auth, game, multiplayer, settings, stats)
  screens/                  # splash, home, game, multiplayer lobby/game, leaderboard, friends, profile, settings
  services/                 # nakama_service.dart (singleton HTTP + WebSocket client)
  theme/                    # app theme (dark)
  widgets/                  # shared widgets (starfield background)
assets/
  images/                   # sprites, meteors, planes, bullets, icons
  audio/                    # bgm, shoot, explosion, game over, win/lose
test/                       # unit + widget tests
android/ ios/ linux/ macos/ web/ windows/   # platform runners
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (bundles Dart)
- A running Nakama server for multiplayer/leaderboard (single-player works offline as guest)

### Install dependencies
```bash
flutter pub get
```

### Run (development)
```bash
flutter run --dart-define=SERVER_KEY=your_dev_key
```

### Build (production)
```bash
flutter build apk --dart-define=ENV=prod --dart-define=SERVER_KEY=your_prod_key --release
```

---

## Configuration (`lib/core/env.dart`)

Environment switching is compile-time via `--dart-define`:

| Setting | Dev | Prod |
|---|---|---|
| `ENV` | `dev` (default) | `prod` |
| Nakama host | `192.168.1.8:7350` (LAN, no SSL) | `api.abba-s.dev:443` (HTTPS) |
| `SERVER_KEY` | dev default in source | **must be passed via `--dart-define` — never hardcoded** |

> The production server key is intentionally **not** in the repository. Pass it at build time only.

---

## Tests

```bash
flutter test
```

---

## Assets

All game art and audio live under `assets/images/` and `assets/audio/`. They are
declared in `pubspec.yaml` and are versioned with the source.

---

## Notes

- `build/`, `.dart_tool/`, `.flutter-plugins-dependencies`, IDE folders and local
  `Captures/` recordings are git-ignored to keep the repo lightweight (source + assets only).
- Multiplayer requires the Nakama backend to be reachable; the app falls back to a
  guest/offline state when the server is unavailable.
