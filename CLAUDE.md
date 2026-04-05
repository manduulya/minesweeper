# Mine Master — Claude Code Guide

## Project Overview

**Mine Master** is a Flutter minesweeper puzzle game with 200 handcrafted levels, a global leaderboard, winning streaks, hints, and offline play. Current version: `1.1.0+4`.

Targets: Android, iOS (primary), with desktop/web scaffolding present but not the focus.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Build Android APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Regenerate launcher icons (after changing assets/appicon2.webp)
flutter pub run flutter_launcher_icons

# Regenerate native splash (after changing splash config in pubspec.yaml)
flutter pub run flutter_native_splash:create
```

## Architecture

```
lib/
  main.dart                  # App entry point, Hive init, Provider setup
  game.dart                  # Core game logic (board state, mine placement, win/lose)
  board.dart                 # Board model
  tile.dart                  # Tile model
  sound_manager.dart         # Audio playback via audioplayers
  screens/
    home.dart                # Home screen
    landing_page.dart        # Landing / onboarding
    animated_splash.dart     # Splash animation
    leaderboard.dart         # Global leaderboard screen
    settings.dart            # Settings screen
    sign_up.dart             # Auth screen
    tutorial_screen.dart     # How-to-play tutorial
    loading.dart             # Loading state screen
  managers/
    game_state_manager.dart  # Provider-based game state (ChangeNotifier)
    game_animation_manager.dart  # Animation controller logic
    game_server_service.dart # Server-side game operations
    responsive_wrapper.dart  # Layout responsiveness helpers
  services/
    api_service.dart         # HTTP calls to backend
    auth_service.dart        # Auth orchestration
    apple_auth_service.dart  # Sign in with Apple
    facebook_auth_service.dart  # Facebook login
    interstitial_ad_service.dart  # Google Mobile Ads
    settings_service.dart    # SharedPreferences wrapper
  hive/
    hive_service.dart        # Hive box access helpers
    offline_sync_service.dart  # Sync offline progress when reconnected
  levels/
    levels_loader.dart       # Loads assets/levels/levels.json
  widgets/                   # Reusable UI components
  dialog_utils/              # Shared dialog helpers
  exceptions/                # Custom exception types
```

## State Management

Uses **Provider** (`provider: ^6.1.1`). The primary ChangeNotifier is `GameStateManager`. Access game state via `context.watch<GameStateManager>()` / `context.read<GameStateManager>()`.

## Local Persistence

**Hive** (`hive: ^2.2.3`, `hive_flutter: ^1.1.0`) is used for structured local storage (player progress, level completion, streaks). `SharedPreferences` handles simple key-value settings via `SettingsService`.

## Networking & Auth

- REST API calls go through `ApiService` (uses `http` package).
- Auth supports Apple Sign-In and Facebook Login.
- Offline-first: progress is stored locally and synced via `OfflineSyncService` when connectivity is restored (`connectivity_plus`).

## Ads

Google Mobile Ads interstitials managed in `InterstitialAdService`. Ads are shown between levels.

## Assets

- Levels defined in `assets/levels/levels.json`.
- Sounds in `assets/sounds/`.
- Custom fonts: Acsioma, Topaz, Agatha (in `assets/fonts/`).
- Images: `.webp` preferred for performance.

## Key Conventions

- Dart file names use `snake_case`.
- Widget files live in `lib/widgets/`; reuse before creating new ones.
- Do not add scroll behavior to game board or home screens (scrolling is intentionally disabled).
- Banner ads sit at the bottom; ensure button layouts account for ad height to avoid overlap.
- Levels advance on win only — losing keeps the player on the current level.
- Avoid double-triggering game-finish logic (race condition was fixed in v1.1.0+4).

## Current Branch

`hive_implementation` — active development branch for Hive integration work.
