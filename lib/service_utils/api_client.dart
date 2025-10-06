import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  /// GET request
  static Future<http.Response> get(String endpoint) async {
    final token = await _getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    print('HERE IS THE URI: $uri');
    return http.get(uri, headers: _buildHeaders(token));
  }

  /// POST request
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    return http.post(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    );
  }

  /// PUT request
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    return http.put(uri, headers: _buildHeaders(token), body: jsonEncode(body));
  }

  /// DELETE request
  static Future<http.Response> delete(String endpoint) async {
    final token = await _getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    return http.delete(uri, headers: _buildHeaders(token));
  }

  /// Helper: get token from SharedPreferences
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Helper: build headers with optional token
  static Map<String, String> _buildHeaders(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
