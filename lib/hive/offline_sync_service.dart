import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';
import '../services/api_service.dart';

class OfflineSyncService {
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

  // ─── Stats ─────────────────────────────────────────────────────────────────

  static void cacheStats(Map<String, dynamic> statsData) {
    HiveService.stats.put('stats', statsData);
    // Sync to score cache — but only if the incoming value is strictly higher
    // than what's already cached. This prevents a default fallback
    // (total_score: 0 from an empty stats box) from wiping a valid score
    // that was seeded by getUserScore() earlier in the session.
    final newScore = statsData['total_score'] as int?;
    if (newScore != null) {
      final existing = getCachedScore() ?? {'score': 0, 'level': 0};
      final currentScore = existing['score'] as int? ?? 0;
      if (newScore > currentScore) {
        existing['score'] = newScore;
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
  /// so the board can use it directly: {score, level}.
  static void cacheScore(Map<String, dynamic> scoreData) {
    HiveService.stats.put('score', scoreData);
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
      current['total_score'] = (current['total_score'] ?? 0) + score;
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
