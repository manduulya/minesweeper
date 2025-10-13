import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../service_utils/constants.dart';
import '../service_utils/api_client.dart';

class ApiService {
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.tokenKey);
  }

  // Authentication headers
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // HTTP client with timeout
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(ApiConstants.requestTimeout);
    } catch (e) {
      rethrow;
    }
  }

  // Register user
  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String countryFlag,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'country_flag': countryFlag,
        }),
      ),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      await _saveToken(data['token']);
      return data;
    } else {
      throw response;
    }
  }

  // Login user
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _makeRequest(
      () => http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await _saveToken(data['token']);
      return data;
    } else {
      throw response;
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
      throw Exception(
        'Failed to fetch revealed cells: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await ApiClient.get('/user/profile');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to load profile: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Start new game
  Future<Map<String, dynamic>> startGame(
    int cols,
    int rows,
    int bombCount,
    List<List<int>> minePositions,
    int levelId,
    int hintCount,
    int winningStreak,
  ) async {
    final response = await ApiClient.post('/game/start', {
      'grid_width': cols,
      'grid_height': rows,
      'mine_count': bombCount,
      'mine_positions': minePositions,
      'level_id': levelId,
      'hints': hintCount,
      'streak': winningStreak,
    });

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to start game: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>?> loadCurrentGame() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/game/current'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load current game: ${response.statusCode}');
    }
  }

  // Update game state
  Future<Map<String, dynamic>> updateGame(
    int gameId,
    List<List<int>> revealedCells,
    List<List<int>> flaggedCells,
  ) async {
    final headers = await _getHeaders();
    final response = await _makeRequest(
      () async => http.put(
        Uri.parse('${ApiConstants.baseUrl}/game/update'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'game_id': gameId,
          'revealed_cells': revealedCells,
          'flagged_cells': flaggedCells,
        }),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to update game: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Finish game
  Future<Map<String, dynamic>> finishGame(
    bool won,
    int level,
    int score,
    int hints,
    int streak,
  ) async {
    final response = await _makeRequest(
      () async => http.post(
        Uri.parse('${ApiConstants.baseUrl}/game/finish'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'won': won,
          'level': level,
          'score': score,
          'hints': hints,
          'streak': streak,
        }),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw response;
    }
  }

  // Get user scores
  Future<List<dynamic>> getUserScores({int limit = 50, int offset = 0}) async {
    final response = await _makeRequest(
      () async => http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/scores/user?limit=$limit&offset=$offset',
        ),
        headers: await _getHeaders(),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw response;
    }
  }

  // Get leaderboard
  Future<List<dynamic>> getLeaderboard({
    int? gridWidth,
    int? gridHeight,
    int? mineCount,
    int limit = 10,
  }) async {
    String url = '${ApiConstants.baseUrl}/leaderboard?limit=$limit';
    if (gridWidth != null && gridHeight != null && mineCount != null) {
      url +=
          '&grid_width=$gridWidth&grid_height=$gridHeight&mine_count=$mineCount';
    }

    final response = await _makeRequest(
      () async => http.get(Uri.parse(url), headers: await _getHeaders()),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw response;
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final response = await _makeRequest(
      () async => http.get(
        Uri.parse('${ApiConstants.baseUrl}/user/stats'),
        headers: await _getHeaders(),
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded as Map<String, dynamic>;
    } else {
      throw response;
    }
  }
}
