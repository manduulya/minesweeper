import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import '../service_utils/api_client.dart';

class AccountNotFoundException implements Exception {}

class WrongPasswordException implements Exception {}

class ServerTimeoutException implements Exception {}

class UnknownLoginException implements Exception {}

// Authentication Service to manage login state
class AuthService extends ChangeNotifier {
  static const String baseUrl = 'http://your-server:3000';
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  String? _username;
  String? _email;
  String? _userId;
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  String? get username => _username;
  String? get email => _email;
  String? get userId => _userId;

  // Initialize auth state from stored preferences
  Future<void> initializeAuth() async {
    print('🔍 AuthService: Starting initialization...');
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _userId = prefs.getString('userId');

      print('🔍 AuthService: Login status = $_isLoggedIn');
      print('🔍 AuthService: Username = $_username');
      print('🔍 AuthService: Email = $_email');

      notifyListeners();
      print('🔍 AuthService: Initialization complete!');
    } catch (e) {
      print('❌ AuthService: Error during initialization: $e');
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    try {
      final response = await ApiClient.post('/auth/login', {
        'username': username,
        'password': password,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _token = data['token'];
        _username = data['user']['username'];
        _email = data['user']['email'];
        _userId = data['user']['id'].toString();
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('auth_token', _token!);
        await prefs.setString('username', _username!);
        await prefs.setString('email', _email!);
        await prefs.setString('userId', _userId!);

        notifyListeners();
        return;
      } else if (response.statusCode == 404) {
        _resetLoginState();
        throw AccountNotFoundException();
      } else if (response.statusCode == 401) {
        _resetLoginState();
        throw WrongPasswordException();
      } else {
        _resetLoginState();
        throw UnknownLoginException();
      }
    } on TimeoutException {
      _resetLoginState();
      throw ServerTimeoutException();
    }
  }

  Future<void> _resetLoginState() async {
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('auth_token');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userId');
  }

  // Register method
  Future<bool> register(
    String username,
    String email,
    String password,
    String country,
  ) async {
    // TODO: Replace with actual API call
    await Future.delayed(Duration(seconds: 1));

    // For demo purposes - replace with actual registration logic
    if (username.isNotEmpty && email.isNotEmpty && password.length >= 6) {
      _isLoggedIn = true;
      _username = username;
      _email = email;
      _userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Store in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', _username!);
      await prefs.setString('email', _email!);
      await prefs.setString('userId', _userId!);

      notifyListeners();
      return true;
    }
    return false;
  }

  // Logout method
  Future<void> logout() async {
    _isLoggedIn = false;
    _username = null;
    _email = null;
    _userId = null;

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userId');

    notifyListeners();
  }

  // Update username
  Future<bool> updateUsername(String newUsername) async {
    try {
      // TODO: Replace with actual API call
      await Future.delayed(Duration(seconds: 1)); // Simulate API delay

      if (newUsername.isNotEmpty) {
        _username = newUsername;

        // Update stored preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', newUsername);

        notifyListeners();
        print('✅ Username updated to: $newUsername');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating username: $e');
      return false;
    }
  }

  // Update password
  Future<bool> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      // TODO: Replace with actual API call to verify current password
      await Future.delayed(Duration(seconds: 1)); // Simulate API delay

      // For demo purposes, assume current password is correct if it's not empty
      if (currentPassword.isNotEmpty && newPassword.length >= 6) {
        // In real implementation, you would:
        // 1. Send current password to server for verification
        // 2. If verified, update password on server
        // 3. Return success/failure based on server response

        print('✅ Password updated successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating password: $e');
      return false;
    }
  }
}
