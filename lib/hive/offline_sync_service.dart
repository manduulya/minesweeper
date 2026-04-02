import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import '../services/api_service.dart';

class OfflineSyncService {
  /// Incremented every time all user data is cleared (logout / account switch).
  /// In-flight background reconciles capture this value before their await and
  /// discard their result if it has changed by the time they resume, preventing
  /// a stale server response from overwriting freshly-loaded new-account data.
  static int _cacheGeneration = 0;
  static int get cacheGeneration => _cacheGeneration;

  /// Returns true if the device has an active network connection.
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  static void cacheUserProfile({
    required String username,
    required String email,
    required String userId,
    required String countryFlag,
    required String token,
  }) {
    HiveService.user.put('profile', {
      'username': username,
      'email': email,
      'userId': userId,
      'countryFlag': countryFlag,
      'token': token,
    });
  }

  static Map<String, dynamic>? getCachedUserProfile() {
    final data = HiveService.user.get('profile');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static void clearUserProfile() => HiveService.user.delete('profile');

  /// Clears all user-specific cached data (stats, score, game state, pending
  /// results). Call this on logout so a new user starts with a clean slate.
  static void clearAllUserData() {
    _cacheGeneration++; // invalidate any in-flight background reconciles
    HiveService.user.delete('profile');
    HiveService.stats.delete('stats');
    HiveService.stats.delete('score');
    HiveService.game.delete('current');
    HiveService.pending.clear();
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────

  static void cacheStats(Map<String, dynamic> statsData) {
    HiveService.stats.put('stats', statsData);
    // Always sync total_score → score cache so the board and home screen
    // stay in agreement. The old "only update if higher" guard was meant to
    // protect against a zero-seeded fallback overwriting a real score, but it
    // also blocked authoritative server data from correcting an inflated cache.
    final newScore = statsData['total_score'] as int?;
    if (newScore != null) {
      final existing = getCachedScore() ?? {'score': 0, 'level': 0};
      final localScore = existing['score'] as int? ?? 0;
      // Only keep the local score if it is strictly higher AND there are
      // pending offline results that haven't been synced yet. Otherwise always
      // trust the server value so a freshly-logged-in account (which may have
      // fewer points than the previous user) gets its correct score cached.
      final hasPendingResults = HiveService.pending.isNotEmpty;
      if (!hasPendingResults || newScore >= localScore) {
        existing['score'] = newScore;
        // Keep level in the score cache in sync with the authoritative stats
        // value so the board always starts at the correct level after login.
        final newLevel = statsData['level'] as int?;
        if (newLevel != null) existing['level'] = newLevel;
        existing['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        HiveService.stats.put('score', existing);
      }
    }
  }

  static Map<String, dynamic>? getCachedStats() {
    final data = HiveService.stats.get('stats');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Cache the user score in the same shape as the /user/score endpoint
  /// so the board can use it directly: {score, level, updatedAt}.
  /// updatedAt (ms since epoch) lets callers detect whether the local
  /// score is newer than whatever the server returns.
  static void cacheScore(Map<String, dynamic> scoreData) {
    final data = Map<String, dynamic>.from(scoreData);
    data['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    HiveService.stats.put('score', data);
  }

  static Map<String, dynamic>? getCachedScore() {
    final data = HiveService.stats.get('score');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Increments local stat counters after an offline game finishes.
  static void updateLocalStats({required bool won, required int score, int? level}) {
    // If the stats box is empty (user went straight to the board without
    // visiting HomeScreen), seed total_score from the score cache so we
    // don't default to 0 and lose the server's real value.
    final seedScore = getCachedScore()?['score'] as int? ?? 0;
    final current = getCachedStats() ?? {
      'games_played': 0,
      'games_won': 0,
      'total_score': seedScore,
      'level': 1,
      'streak': 0,
      'hints': 3,
    };
    current['games_played'] = (current['games_played'] ?? 0) + 1;
    if (won) {
      current['games_won'] = (current['games_won'] ?? 0) + 1;
      // score is already the new cumulative total (game.score after win),
      // not a delta — set directly instead of adding to avoid double-counting.
      current['total_score'] = score;
    }
    cacheStats(current); // also syncs total_score → score cache via cacheStats()

    // Only update the level field — score is already handled by cacheStats().
    // A separate score += here would double-count because cacheStats() already
    // wrote the new total_score into the score cache.
    if (level != null) {
      final cachedScore = getCachedScore() ?? {'score': 0, 'level': 0};
      cachedScore['level'] = level;
      cacheScore(cachedScore);
    }
  }

  // ─── Game State ────────────────────────────────────────────────────────────

  /// Saves current game state so it can be restored after an offline session.
  /// The [gameState] map mirrors the shape returned by the server's
  /// `/game/current` endpoint so that `_loadActiveGame()` in board.dart
  /// can reconstruct the game without any special-casing.
  static void cacheGameState(Map<String, dynamic> gameState) {
    HiveService.game.put('current', gameState);
  }

  static Map<String, dynamic>? getCachedGameState() {
    final data = HiveService.game.get('current');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static void clearGameState() => HiveService.game.delete('current');

  // ─── Pending Results (offline sync queue) ─────────────────────────────────

  static void queuePendingResult({
    required bool won,
    required int level,
    required int score,
    required int hints,
    required int streak,
  }) {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    HiveService.pending.put(key, {
      'won': won,
      'level': level,
      'score': score,
      'hints': hints,
      'streak': streak,
      'timestamp': int.parse(key),
    });
  }

  static int get pendingCount => HiveService.pending.length;

  /// Attempts to push all queued offline results to the server.
  /// Stops at the first failure so results stay in order.
  static Future<void> syncPendingResults() async {
    if (!await isOnline()) return;
    if (HiveService.pending.isEmpty) return;

    final apiService = ApiService();
    final keys = HiveService.pending.keys.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));

    for (final key in keys) {
      final raw = HiveService.pending.get(key);
      if (raw == null) continue;
      final result = Map<String, dynamic>.from(raw as Map);

      try {
        await apiService.finishGame(
          result['won'] as bool,
          result['level'] as int,
          result['score'] as int,
          result['hints'] as int,
          result['streak'] as int,
        );
        await HiveService.pending.delete(key);
      } catch (_) {
        break; // leave remaining in queue, retry next time
      }
    }
  }
}
