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

# Build Android APK (debug — uses test AdMob IDs, no signing required)
flutter build apk --debug

# Build Android APK (release — uses production AdMob IDs, requires signing)
flutter build apk --release

# Build iOS (release)
flutter build ios --release

# Install latest build to connected device
flutter install

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
    mode_selection_screen.dart  # REVEAL THE WORLD vs CAREER MODE choice
    world_map_screen.dart    # Pannable/zoomable SVG world map
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
    interstitial_ad_service.dart  # Interstitial ads (between career levels; on country reveal)
    rewarded_ad_service.dart     # Rewarded ads (watch ad to earn a hint)
    settings_service.dart    # SharedPreferences wrapper
  hive/
    hive_service.dart        # Hive box access helpers
    offline_sync_service.dart  # Sync offline progress when reconnected
  levels/
    levels_loader.dart       # Loads assets/levels/levels.json
  widgets/
    peel_particle_system.dart    # Singleton CustomPainter overlay — drives all tile-peel particles
  widgets/                   # Other reusable UI components
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

All ad IDs switch automatically between **test** (debug/profile builds) and **production** (release builds) via `kReleaseMode`. Never hardcode production IDs — always use the getter pattern in the service files.

### Interstitial (`InterstitialAdService`)
- **Career mode**: shown every 5 rounds via `onRoundComplete()`
- **Reveal the World**: shown every time the player reveals a country via `showAdNow()` — fires after the player taps AWESOME! on the fun fact dialog
- Preload with `preloadAd()`; the service reloads automatically after each show

### Rewarded (`RewardedAdService`)
- Shown when the player taps the hint button with `hintCount == 0`
- On reward granted: `hintCount` is incremented by 1
- Preload with `preloadAd()`; `onAdLoadStateChanged` callback lets the UI react to load state
- The hint button UI shows a "watch ad" affordance only when `isLoaded == true`

### Ad Unit IDs

| Service | Platform | Debug | Release |
|---|---|---|---|
| Interstitial | Android | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-7775348743322565/9700217077` |
| Interstitial | iOS | `ca-app-pub-3940256099942544/4411468910` | `ca-app-pub-7775348743322565/8718307892` |
| Rewarded | Android | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-7775348743322565/5646307441` |
| Rewarded | iOS | `ca-app-pub-3940256099942544/1712485313` | `ca-app-pub-7775348743322565/3638044050` |

### Native App ID configuration
- **Android**: `manifestPlaceholders["admobAppId"]` set per build type in `android/app/build.gradle.kts`; referenced as `${admobAppId}` in `AndroidManifest.xml`
- **iOS**: `ADMOB_APP_ID` set in `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`; referenced as `$(ADMOB_APP_ID)` in `ios/Runner/Info.plist`

## Assets

- Levels defined in `assets/levels/levels.json`.
- Sounds in `assets/sounds/`.
- Custom fonts: Acsioma, Topaz, Agatha (in `assets/fonts/`).
- Images: `.webp` preferred for performance.
- World map SVG: `assets/world.svg` (source), `assets/world_colored.svg` (generated — run `python color_map.py` to regenerate).

## Key Conventions

- Dart file names use `snake_case`.
- Widget files live in `lib/widgets/`; reuse before creating new ones.
- Do not add scroll behavior to game board or home screens (scrolling is intentionally disabled).
- Banner ads sit at the bottom; ensure button layouts account for ad height to avoid overlap.
- Levels advance on win only — losing keeps the player on the current level.
- Avoid double-triggering game-finish logic (race condition was fixed in v1.1.0+4).

## Tile-Peel Animation

All tile-reveal peel particles are managed by a single `PeelParticleSystem` singleton (`lib/widgets/peel_particle_system.dart`). It renders every active particle on one `CustomPainter` canvas via a single `OverlayEntry`, driven by `SchedulerBinding.scheduleFrameCallback`. Each `TileWidget` is wrapped in a `RepaintBoundary` to isolate repaints.

Do **not** create per-tile `OverlayEntry` instances or `AnimationController`s for peel particles — that approach caused severe lag when 50+ tiles revealed simultaneously.

## Current Branch

`world-map` — active development branch.

---

## Reveal the World Feature

A second game mode accessible from the home screen via a mode selection screen (PLAY GAME → REVEAL THE WORLD or CAREER MODE).

### Vision
- A pannable/zoomable world map where every country starts covered by minesweeper fog-of-war tiles
- Player taps a country → plays a minesweeper board for that country
- Win: tiles dissolve, country is revealed, a flag icon appears
- Lose: only that country's board resets, map progress is kept
- Tapping a revealed flag shows a popup with a fun fact
- Future: globe-in-space view when zoomed out, crossfading to flat map when zoomed in

### Key Files

```
lib/screens/
  mode_selection_screen.dart   # Two-button screen: "REVEAL THE WORLD" / "CAREER MODE"
  world_map_screen.dart        # Scaffold + back button; hosts GlobeWidget

lib/widgets/
  globe_widget.dart            # All Reveal the World logic: globe shader, SVG hit-testing,
                               # country boards, reveal state, fun fact dialogs, ad triggering

assets/
  world.svg                    # Source SVG (simplemaps.com, MIT license, 2000×857 viewBox)
  world_colored.svg            # Generated — DO NOT edit manually, run color_map.py instead
  shaders/globe.frag           # Fragment shader — renders equirectangular SVG texture as a globe

color_map.py                   # Python script (project root) — regenerates world_colored.svg
```

### SVG Map Details

- Source: simplemaps.com MIT-licensed world SVG, equirectangular projection, viewBox `0 0 2000 857`
- Single-territory countries use `id="ISO"` (e.g. `id="NG"` for Nigeria)
- Multi-territory countries use `class="CountryName"` (e.g. `class="Canada"`)
- `CLASS_TO_ISO` in `color_map.py` maps SVG class names → ISO codes
- Island nations with no land borders must be explicitly added to both `CLASS_TO_ISO` **and** `ADJACENCY` (with an empty list `[]`) or they won't be colored

### Coloring (Four-Color Theorem)

Run `python color_map.py` from the project root to regenerate `assets/world_colored.svg`.

- Uses greedy graph coloring so no two bordering countries share a color
- Palette: `#FFDD00` (yellow), `#FF5722` (deep orange), `#4CAF50` (green), `#9C27B0` (purple)
- Ocean/background: `#0B1E3D` (dark navy)
- Large dominant countries are pre-seeded to avoid color imbalance:
  - Russia → purple (prevents too much yellow)
  - China, USA → deep orange
  - Brazil → green
  - Australia → yellow
- After regenerating, do a **full app restart** (not hot reload) to pick up the new asset

### InteractiveViewer Settings

```dart
InteractiveViewer(
  minScale: 0.5,
  maxScale: 30.0,          // 30x needed to select small European countries
  boundaryMargin: EdgeInsets.all(80),
)
```

### What's Built

- Globe shader renders the SVG as a rotatable, zoomable 3D sphere
- Auto-rotation when zoom ≤ 2×; stops on interaction
- Per-country tap detection via `Path.contains()` + inverse projection through shader math
- Country grid generated from SVG path shape (300–500 inside cells, bomb count = cells/8)
- Full minesweeper board playable per country in a modal dialog
- Win → country coloured with dominant flag colour on the globe
- Fun fact dialog shown after win (400ms delay); AWESOME! button triggers interstitial ad
- Tapping an already-revealed country shows the fun fact dialog again (no ad, X button visible)
- `_GlobeWidgetState.revealCountry(iso)` patches the SVG string and recaptures the GPU texture

### Planned Next Steps

1. Hive storage for map progress (persist which countries are revealed across sessions)
2. Tile dissolve / reveal animation when a country is won
3. Flag icon on the globe for revealed countries
4. Globe-in-space view: crossfade at zoom threshold
