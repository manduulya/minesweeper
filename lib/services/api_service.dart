import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../service_utils/constants.dart';
import '../service_utils/api_client.dart';
import '../exceptions/app_exceptions.dart';

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
    String? countryFlag,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          if (countryFlag != null && countryFlag.isNotEmpty)
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

  Future<Map<String, dynamic>> updateGame(
    int gameId,
    List<List<int>> revealedCells,
    List<List<int>> flaggedCells, {
    int? hintCount,
  }) async {
    final response = await _makeRequest(
      () async => http.put(
        Uri.parse('${ApiConstants.baseUrl}/game/update'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'game_id': gameId,
          'revealed_cells': revealedCells,
          'flagged_cells': flaggedCells,
          if (hintCount != null) 'hints': hintCount,
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

  Future<Map<String, dynamic>?> getUserScore() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/user/score'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // No score yet, return defaults
        return {'score': 0, 'level': 0};
      } else {
        throw Exception('Failed to fetch user score: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user score: $e');
      return null;
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

  Future<List<Map<String, dynamic>>> getLeaderboard({
    int? levelId,
    int limit = 50,
  }) async {
    String url = '${ApiConstants.baseUrl}/leaderboard?limit=$limit';
    if (levelId != null) {
      url += '&level_id=$levelId';
    }

    final response = await _makeRequest(
      () async => http.get(Uri.parse(url), headers: await _getHeaders()),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load leaderboard: ${response.statusCode}');
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

  Future<void> resetPassword({
    required String username,
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Password reset successful
        final data = jsonDecode(response.body);
        print('Password reset: ${data['message']}');
        return;
      } else if (response.statusCode == 404) {
        // User not found with this username/email combination
        throw UserNotFoundException(
          'No account found with this username and email',
        );
      } else if (response.statusCode == 400) {
        // Invalid request (validation error)
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Invalid request');
      } else {
        // Other error
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to reset password');
      }
    } on TimeoutException {
      throw ServerTimeoutException();
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is UserNotFoundException ||
          e is ServerTimeoutException ||
          e is NetworkException) {
        rethrow;
      }
      throw Exception('Password reset failed: $e');
    }
  }

  Future<Map<String, dynamic>> loginWithApple({
    required String appleId,
    String? name,
    String? email,
    String? identityToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/auth/apple'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'apple_id': appleId,
              'name': name,
              'email': email,
              'identity_token': identityToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        return data;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Invalid Apple data');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Apple login failed');
      }
    } on TimeoutException {
      throw ServerTimeoutException();
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      if (e is ServerTimeoutException || e is NetworkException) rethrow;
      throw Exception('Apple login failed: $e');
    }
  }

  Future<Map<String, dynamic>> loginWithFacebook({
    required String facebookId,
    required String name,
    String? email,
  }) async {
    print('📗 [API Service] Starting Facebook login API call...');
    print('📗 [API Service] Data being sent:');
    print('  - Facebook ID: $facebookId');
    print('  - Name: $name');
    print('  - Email: ${email ?? "EMPTY"}');

    try {
      final body = jsonEncode({
        'facebook_id': facebookId,
        'name': name,
        'email': email,
      });

      print('📗 [API Service] Request body: $body');
      print(
        '📗 [API Service] Sending POST to: ${ApiConstants.baseUrl}/auth/facebook',
      );

      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/auth/facebook'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print('📗 [API Service] Response received:');
      print('  - Status code: ${response.statusCode}');
      print('  - Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [API Service] Success! Parsing response...');
        final data = jsonDecode(response.body);

        print('📗 [API Service] Parsed data:');
        print('  - User: ${data['user']}');
        print('  - Token: ${data['token']?.substring(0, 20)}...');

        // Store token
        print('📗 [API Service] Storing auth token...');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        print('✅ [API Service] Token stored successfully');

        return data;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        print('❌ [API Service] 400 Bad Request: ${data['error']}');
        throw Exception(data['error'] ?? 'Invalid Facebook data');
      } else {
        final data = jsonDecode(response.body);
        print('❌ [API Service] Error ${response.statusCode}: ${data['error']}');
        throw Exception(data['error'] ?? 'Facebook login failed');
      }
    } on TimeoutException {
      print('❌ [API Service] Request timeout!');
      throw ServerTimeoutException();
    } on SocketException catch (e) {
      print('❌ [API Service] Network error: $e');
      throw NetworkException();
    } catch (e) {
      print('❌ [API Service] Unexpected error: $e');
      if (e is ServerTimeoutException || e is NetworkException) {
        rethrow;
      }
      throw Exception('Facebook login failed: $e');
    }
  }
}
