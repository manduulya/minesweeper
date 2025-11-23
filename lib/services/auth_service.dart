import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import '../service_utils/api_client.dart';
import '../services/settings_service.dart';

class AccountNotFoundException implements Exception {}

class WrongPasswordException implements Exception {}

class ServerTimeoutException implements Exception {}

class UnknownLoginException implements Exception {}

// Authentication Service to manage login state
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  String? _username;
  String? _email;
  String? _userId;
  String? _countryFlag;
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  String? get username => _username;
  String? get email => _email;
  String? get userId => _userId;
  String? get countryFlag => _countryFlag;

  // Initialize auth state from stored preferences
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      _token = prefs.getString('auth_token');
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _userId = prefs.getString('userId');
      _countryFlag = prefs.getString('country_flag');

      // If logged in, fetch fresh profile data
      if (_isLoggedIn && _token != null) {
        await fetchUserProfile();
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing auth: $e');
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  // Fetch user profile from API
  Future<void> fetchUserProfile() async {
    try {
      if (_token == null) {
        print('⚠️ No auth token available');
        return;
      }

      final response = await ApiClient.get(
        '/user/profile',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _userId = data['id']?.toString();
        _username = data['username'];
        _email = data['email'];
        _countryFlag = data['country_flag'] ?? 'international';

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (_username != null) await prefs.setString('username', _username!);
        if (_email != null) await prefs.setString('email', _email!);
        if (_countryFlag != null) {
          await prefs.setString('country_flag', _countryFlag!);
        }

        // Update SettingsService with country flag
        final settingsService = SettingsService();
        settingsService.setCountryFlagFromAuth(_countryFlag ?? 'international');

        notifyListeners();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
      } else {}
    } on TimeoutException {
      print('❌ Profile fetch timeout');
    } catch (e) {
      print('❌ Error fetching user profile: $e');
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
        _countryFlag = data['user']['country_flag'] ?? 'international';
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('auth_token', _token!);
        await prefs.setString('username', _username!);
        await prefs.setString('email', _email!);
        await prefs.setString('userId', _userId!);
        await prefs.setString('country_flag', _countryFlag!);

        // Update SettingsService
        final settingsService = SettingsService();
        settingsService.setAuthToken(_token);
        settingsService.setCountryFlagFromAuth(_countryFlag!);

        // Fetch full profile to ensure we have all data
        await fetchUserProfile();

        notifyListeners();
        return;
      } else if (response.statusCode == 404) {
        await _resetLoginState();
        throw AccountNotFoundException();
      } else if (response.statusCode == 401) {
        await _resetLoginState();
        throw WrongPasswordException();
      } else {
        await _resetLoginState();
        throw UnknownLoginException();
      }
    } on TimeoutException {
      await _resetLoginState();
      throw ServerTimeoutException();
    }
  }

  Future<void> _resetLoginState() async {
    _isLoggedIn = false;
    _token = null;
    _username = null;
    _email = null;
    _userId = null;
    _countryFlag = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('auth_token');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userId');
    await prefs.remove('country_flag');

    notifyListeners();
  }

  // Register method
  Future<bool> register(
    String username,
    String email,
    String password,
    String countryFlag,
  ) async {
    try {
      final response = await ApiClient.post('/auth/register', {
        'username': username,
        'email': email,
        'password': password,
        'country_flag': countryFlag,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        _token = data['token'];
        _username = data['user']['username'];
        _email = data['user']['email'];
        _userId = data['user']['id'].toString();
        _countryFlag = data['user']['country_flag'] ?? countryFlag;
        _isLoggedIn = true;

        // Store in shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('auth_token', _token!);
        await prefs.setString('username', _username!);
        await prefs.setString('email', _email!);
        await prefs.setString('userId', _userId!);
        await prefs.setString('country_flag', _countryFlag!);

        // Update SettingsService
        final settingsService = SettingsService();
        settingsService.setAuthToken(_token);
        settingsService.setCountryFlagFromAuth(_countryFlag!);

        // Fetch full profile to ensure we have all data
        await fetchUserProfile();

        notifyListeners();
        return true;
      } else {
        print('❌ Registration failed: ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      print('❌ Registration timeout');
      return false;
    } catch (e) {
      print('❌ Registration error: $e');
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    _isLoggedIn = false;
    _token = null;
    _username = null;
    _email = null;
    _userId = null;
    _countryFlag = null;

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('auth_token');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userId');
    await prefs.remove('country_flag');

    notifyListeners();
  }

  // Update username
  Future<bool> updateUsername(String newUsername) async {
    try {
      if (_token == null) {
        print('❌ No auth token available');
        return false;
      }

      final response = await ApiClient.put('/user/profile', {
        'username': newUsername,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _username = newUsername;

        // Update stored preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', newUsername);

        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        print('❌ Failed to update username: ${error['error']}');
        return false;
      }
    } on TimeoutException {
      print('❌ Update username timeout');
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
      if (_token == null) {
        print('❌ No auth token available');
        return false;
      }

      final response = await ApiClient.put('/user/profile', {
        'current_password': currentPassword,
        'new_password': newPassword,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Password updated successfully');
        return true;
      } else {
        final error = json.decode(response.body);
        print('❌ Failed to update password: ${error['error']}');
        return false;
      }
    } on TimeoutException {
      print('❌ Update password timeout');
      return false;
    } catch (e) {
      print('❌ Error updating password: $e');
      return false;
    }
  }
}
