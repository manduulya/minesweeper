import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../service_utils/constants.dart';
import '../services/api_service.dart';

class GameServerService {
  final ApiService _apiService = ApiService();

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
    return await _apiService.startGame(
      cols,
      rows,
      bombCount,
      minePositions,
      level,
      hintCount,
      winningStreak,
    );
  }

  Future<void> updateServerGame({
    required int gameId,
    required List<List<int>> revealedCells,
    required List<List<int>> flaggedCells,
    required int hintCount,
  }) async {
    await _apiService.updateGame(
      gameId,
      revealedCells,
      flaggedCells,
      hintCount: hintCount,
    );
  }

  Future<Map<String, dynamic>> finishServerGame({
    required bool won,
    required int level,
    required int totalScore,
    required int hints,
    required int streak,
  }) async {
    return await _apiService.finishGame(won, level, totalScore, hints, streak);
  }

  Future<Map<String, dynamic>?> loadCurrentGame() async {
    return await _apiService.loadCurrentGame();
  }

  Future<Map<String, dynamic>?> getUserScore() async {
    return await _apiService.getUserScore();
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
      throw Exception('Failed to fetch flagged cells: ${response.statusCode}');
    }
  }
}
