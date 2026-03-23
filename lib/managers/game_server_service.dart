import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../service_utils/constants.dart';
import '../services/api_service.dart';
import '../hive/offline_sync_service.dart';

class GameServerService {
  final ApiService _apiService = ApiService();

  // In-memory cache so repeated getUserScore() calls within the same session
  // don't each wait for a network timeout when the server is unreachable.
  static Map<String, dynamic>? _scoreCache;
  static DateTime? _scoreCacheTime;
  static const _scoreCacheTtl = Duration(minutes: 2);

  /// Call at the start of every board session so the first getUserScore()
  /// always fetches a fresh value instead of returning a stale TTL hit
  /// from the previous session.
  void invalidateScoreCache() {
    _scoreCache = null;
    _scoreCacheTime = null;
  }

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
    try {
      final result = await _apiService
          .finishGame(won, level, totalScore, hints, streak)
          .timeout(const Duration(seconds: 5));
      OfflineSyncService.clearGameState();
      // Update score cache directly from the submitted score — no extra
      // getUserScore() round-trip needed. _initializeGameFromLevel will hit
      // this in-memory cache instantly, eliminating the display delay.
      _scoreCache = {'score': totalScore, 'level': level};
      _scoreCacheTime = DateTime.now();
      OfflineSyncService.cacheScore(Map<String, dynamic>.from(_scoreCache!));
      return result;
    } catch (_) {
      // Offline: queue result and update local stats optimistically
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
      _scoreCache = null; // invalidate so next level reads updated local score
      return {'won': won, 'score': totalScore, 'offline': true};
    }
  }

  Future<Map<String, dynamic>?> loadCurrentGame() async {
    try {
      final serverGame = await _apiService
          .loadCurrentGame()
          .timeout(const Duration(seconds: 5));
      if (serverGame != null) {
        final status = serverGame['game_status'] as String? ?? 'active';
        // Only resume an active server game. A completed server game is stale
        // — ignore it and fall through to check the Hive cache instead.
        // Do NOT call clearGameState() here: the user may have a valid
        // mid-game in Hive that started while the server was unreachable.
        if (status == 'active') return serverGame;
      }
    } catch (_) {
      // Server unreachable — fall through to Hive cache
    }

    final cached = OfflineSyncService.getCachedGameState();
    if (cached == null) return null;
    // Safety guard: Hive cache should always be 'active' (we never write
    // won/lost there), but if it somehow isn't, clear it and start fresh.
    final cachedStatus = cached['game_status'] as String? ?? 'active';
    if (cachedStatus != 'active') {
      OfflineSyncService.clearGameState();
      return null;
    }
    return cached;
  }

  Future<Map<String, dynamic>?> getUserScore() async {
    // Return in-memory cache if still fresh — avoids multiple 5s timeouts
    // when the board calls getUserScore() several times during load.
    final now = DateTime.now();
    if (_scoreCache != null &&
        _scoreCacheTime != null &&
        now.difference(_scoreCacheTime!) < _scoreCacheTtl) {
      return _scoreCache;
    }

    try {
      final result = await _apiService
          .getUserScore()
          .timeout(const Duration(seconds: 5));
      // ApiService.getUserScore() swallows SocketException and returns null,
      // so a null result here means the network is unreachable — treat it
      // the same as an exception and fall through to the Hive cache.
      if (result != null) {
        _scoreCache = Map<String, dynamic>.from(result);
        _scoreCacheTime = now;
        OfflineSyncService.cacheScore(_scoreCache!);
        return _scoreCache;
      }
    } catch (_) {}

    // Offline fallback — return Hive-persisted score so the board never
    // starts with score = 0 just because the server was unreachable.
    final hive = OfflineSyncService.getCachedScore() ?? {'score': 0, 'level': 0};
    _scoreCache = hive;
    _scoreCacheTime = now;
    return hive;
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
