import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../service_utils/constants.dart';
import '../services/api_service.dart';
import '../hive/offline_sync_service.dart';

class GameServerService {
  final ApiService _apiService = ApiService();

/// No-op kept for call-site compatibility — score is now always read
  /// directly from Hive so there is no in-memory TTL cache to invalidate.
  void invalidateScoreCache() {}

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> startServerGame({
    required int cols,
    required int rows,
    required int bombCount,
    required List<List<int>> minePositions,
    required int level,
    required int hintCount,
    required int winningStreak,
  }) async {
    int gameId;
    try {
      final result = await _apiService.startGame(
        cols,
        rows,
        bombCount,
        minePositions,
        level,
        hintCount,
        winningStreak,
      );
      gameId = result['game_id'] is int
          ? result['game_id'] as int
          : int.parse(result['game_id'].toString());
    } catch (_) {
      // Offline: use a negative local ID to distinguish from server IDs
      gameId = -DateTime.now().millisecondsSinceEpoch;
    }

    // Always persist the full initial game state to Hive so the game can be
    // resumed even if the server goes down and the app is restarted.
    OfflineSyncService.cacheGameState({
      'game_id': gameId,
      'level': level,
      'rows': rows,
      'cols': cols,
      'bombs': bombCount,
      'mine_positions': minePositions,
      'revealed_cells': <List<int>>[],
      'flagged_cells': <List<int>>[],
      'hints': hintCount,
      'streak': winningStreak,
      'game_status': 'active',
    });

    return {'game_id': gameId};
  }

  Future<void> updateServerGame({
    required int gameId,
    required List<List<int>> revealedCells,
    required List<List<int>> flaggedCells,
    required int hintCount,
  }) async {
    // Always keep Hive in sync so progress survives a server outage or app restart
    final cached = OfflineSyncService.getCachedGameState() ?? {};
    cached['revealed_cells'] = revealedCells;
    cached['flagged_cells'] = flaggedCells;
    cached['hints'] = hintCount;
    OfflineSyncService.cacheGameState(cached);

    if (gameId < 0) return; // offline-only game, nothing to sync

    try {
      await _apiService.updateGame(
        gameId,
        revealedCells,
        flaggedCells,
        hintCount: hintCount,
      );
    } catch (_) {
      // Server unreachable — Hive already updated above, will sync later
    }
  }

  Future<Map<String, dynamic>> finishServerGame({
    required bool won,
    required int level,
    required int totalScore,
    required int hints,
    required int streak,
  }) async {
    // On a win, cache both score and the completed level so the next session
    // starts at the correct next level. On a loss, only cache the score —
    // the level in Hive must remain the last *completed* level, not the
    // current (failed) one, otherwise _determineNextLevelIndex advances
    // the level even though nothing was completed.
    if (won) {
      OfflineSyncService.cacheScore({'score': totalScore, 'level': level});
    } else {
      final existing = OfflineSyncService.getCachedScore() ?? {'score': 0, 'level': 0};
      existing['score'] = totalScore;
      OfflineSyncService.cacheScore(existing);
    }

    try {
      final result = await _apiService
          .finishGame(won, level, totalScore, hints, streak)
          .timeout(const Duration(seconds: 5));
      OfflineSyncService.clearGameState();
      return result;
    } catch (_) {
      // Offline: queue result and update local stats optimistically.
      // Hive score is already written above, so the next level load is correct.
      OfflineSyncService.queuePendingResult(
        won: won,
        level: level,
        score: totalScore,
        hints: hints,
        streak: streak,
      );
      OfflineSyncService.updateLocalStats(
        won: won,
        score: totalScore,
        level: level,
      );
      OfflineSyncService.clearGameState();
      return {'won': won, 'score': totalScore, 'offline': true};
    }
  }

  Future<Map<String, dynamic>?> loadCurrentGame() async {
    try {
      final serverGame = await _apiService
          .loadCurrentGame()
          .timeout(const Duration(seconds: 5));
      if (serverGame != null) {
        final status = serverGame['game_status'] as String? ?? '';
        // Only resume an active server game. A completed server game is stale
        // — ignore it and fall through to check the Hive cache instead.
        // Do NOT call clearGameState() here: the user may have a valid
        // mid-game in Hive that started while the server was unreachable.
        if (status == 'active' || status == 'playing') return serverGame;
      }
    } catch (_) {
      // Server unreachable — fall through to Hive cache
    }

    final cached = OfflineSyncService.getCachedGameState();
    if (cached == null) return null;
    // Safety guard: Hive cache should always be 'active' or 'playing' (we
    // never write won/lost there), but if it somehow isn't, clear it and
    // start fresh.
    final cachedStatus = cached['game_status'] as String? ?? '';
    if (cachedStatus != 'active' && cachedStatus != 'playing') {
      OfflineSyncService.clearGameState();
      return null;
    }
    return cached;
  }

  /// Fetches fresh hints and streak from the server (or Hive fallback).
  ///
  /// Returns a map with at minimum `{hints, streak}`. On success, also caches
  /// the full stats blob so the rest of the session stays in sync.
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final result = await _apiService
          .getUserStats()
          .timeout(const Duration(seconds: 5));
      // Cache so offline fallback and home screen stay current.
      OfflineSyncService.cacheStats(result);
      return result;
    } catch (_) {
      // Server unreachable — fall back to Hive, then hard defaults.
      final cached = OfflineSyncService.getCachedStats();
      if (cached != null) return cached;
      return {'hints': 3, 'streak': 0};
    }
  }

  /// Fetches the score from the server first (authoritative source for level).
  /// Updates Hive with the server result so subsequent reads are correct.
  /// Falls back to Hive if the server is unreachable (offline scenario).
  /// If Hive is ahead due to unsynced pending results, keeps the local score
  /// but always trusts the server's level.
  Future<Map<String, dynamic>?> getUserScore() async {
    final generationAtStart = OfflineSyncService.cacheGeneration;
    try {
      final result = await _apiService
          .getUserScore()
          .timeout(const Duration(seconds: 5));

      if (result == null) {
        return OfflineSyncService.getCachedScore() ?? {'score': 0, 'level': 0};
      }

      // Discard if account switched while awaiting.
      if (OfflineSyncService.cacheGeneration != generationAtStart) {
        return OfflineSyncService.getCachedScore() ?? {'score': 0, 'level': 0};
      }

      final serverScore = result['score'] as int? ?? 0;
      final serverLevel = result['level'] as int? ?? 0;
      final hive = OfflineSyncService.getCachedScore() ?? {'score': 0, 'level': 0};
      final localScore = hive['score'] as int? ?? 0;
      final hasPending = OfflineSyncService.pendingCount > 0;

      // Always trust server level. For score, keep local if pending results
      // haven't synced yet and local is higher (offline-earned points).
      final resolvedScore = (hasPending && localScore > serverScore) ? localScore : serverScore;
      final resolved = {'score': resolvedScore, 'level': serverLevel};
      OfflineSyncService.cacheScore(resolved);
      return resolved;
    } catch (_) {
      // Network unreachable — fall back to Hive.
      return OfflineSyncService.getCachedScore() ?? {'score': 0, 'level': 0};
    }
  }

  Future<List<List<int>>> getRevealedCells(int gameId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/game/$gameId/revealed'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<List<int>>.from(
        (data['revealed_cells'] as List).map((row) => List<int>.from(row)),
      );
    } else {
      throw Exception('Failed to fetch revealed cells: ${response.statusCode}');
    }
  }

  Future<List<List<int>>> getFlaggedCells(int gameId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/game/$gameId/flagged'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<List<int>>.from(
        (data['flagged_cells'] as List).map((row) => List<int>.from(row)),
      );
    } else {
      throw Exception(
        'Failed to fetch flagged cells: ${response.statusCode}',
      );
    }
  }
}
