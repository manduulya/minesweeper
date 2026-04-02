import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import '../service_utils/api_client.dart';
import '../service_utils/constants.dart';
import '../services/settings_service.dart';
import '../exceptions/app_exceptions.dart';
import '../hive/offline_sync_service.dart';

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
  String? _authProvider; // 'local', 'facebook', 'apple'
  bool _isLoggedIn = false;
  bool _isAuthenticated = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  String? get username => _username;
  String? get email => _email;
  String? get userId => _userId;
  String? get countryFlag => _countryFlag;
  String? get authProvider => _authProvider;
  bool get isAuthenticated => _isAuthenticated;
  bool get isSocialLogin => _authProvider == 'facebook' || _authProvider == 'apple';

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
      _authProvider = prefs.getString('auth_provider') ?? 'local';

      if (_isLoggedIn && _token != null) {
        final online = await OfflineSyncService.isOnline();
        if (online) {
          await fetchUserProfile(); // refreshes from server + updates cache
        } else {
          // Restore from Hive cache when offline
          final cached = OfflineSyncService.getCachedUserProfile();
          if (cached != null) {
            _username = cached['username'] ?? _username;
            _email = cached['email'] ?? _email;
            _userId = cached['userId'] ?? _userId;
            _countryFlag = cached['countryFlag'] ?? _countryFlag;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> setUserData(
    String username,
    String token, {
    String? email,
    String? userId,
    String? countryFlag,
    String? authProvider,
  }) async {
    // Clear any previous user's cached data so a new login always starts fresh.
    OfflineSyncService.clearAllUserData();

    _username = username;
    _token = token;
    _email = email;
    _userId = userId;
    _countryFlag = countryFlag ?? ApiConstants.kNoCountry;
    _authProvider = authProvider ?? 'local';
    _isAuthenticated = true;
    _isLoggedIn = true;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('auth_token', token);
    await prefs.setString('username', username);
    if (email != null) await prefs.setString('email', email);
    if (userId != null) await prefs.setString('userId', userId);
    await prefs.setString('country_flag', _countryFlag!);
    await prefs.setString('auth_provider', _authProvider!);

    // Cache to Hive for offline use
    OfflineSyncService.cacheUserProfile(
      username: username,
      email: email ?? '',
      userId: userId ?? '',
      countryFlag: _countryFlag!,
      token: token,
    );

    // Update SettingsService
    final settingsService = SettingsService();
    settingsService.setAuthToken(token);
    settingsService.setCountryFlagFromAuth(_countryFlag!);

    notifyListeners();
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
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        _userId = data['id']?.toString();
        _username = data['username'];
        _email = data['email'];
        _countryFlag = data['country_flag'] ?? ApiConstants.kNoCountry;
        final authMethod = data['auth_method'];
        if (authMethod != null && authMethod != 'traditional') {
          _authProvider = authMethod;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_provider', _authProvider!);
        }

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (_username != null) await prefs.setString('username', _username!);
        if (_email != null) await prefs.setString('email', _email!);
        if (_countryFlag != null) {
          await prefs.setString('country_flag', _countryFlag!);
        }

        // Update Hive cache
        if (_token != null) {
          OfflineSyncService.cacheUserProfile(
            username: _username ?? '',
            email: _email ?? '',
            userId: _userId ?? '',
            countryFlag: _countryFlag ?? ApiConstants.kNoCountry,
            token: _token!,
          );
        }

        // Update SettingsService with country flag
        final settingsService = SettingsService();
        settingsService.setCountryFlagFromAuth(
          _countryFlag ?? ApiConstants.kNoCountry,
        );

        notifyListeners();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
      }
    } on TimeoutException {
      // Offline or server unreachable — silently continue with cached data
    } catch (_) {
      // Network error — silently continue with cached data
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
        _countryFlag = data['user']['country_flag'] ?? ApiConstants.kNoCountry;
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('auth_token', _token!);
        await prefs.setString('username', _username!);
        await prefs.setString('email', _email!);
        await prefs.setString('userId', _userId!);
        await prefs.setString('country_flag', _countryFlag!);

        // Cache to Hive for offline use
        OfflineSyncService.cacheUserProfile(
          username: _username!,
          email: _email!,
          userId: _userId!,
          countryFlag: _countryFlag!,
          token: _token!,
        );

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
    _authProvider = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('auth_token');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userId');
    await prefs.remove('country_flag');
    await prefs.remove('auth_provider');

    OfflineSyncService.clearAllUserData();

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

        // Cache to Hive for offline use
        OfflineSyncService.cacheUserProfile(
          username: _username!,
          email: _email!,
          userId: _userId!,
          countryFlag: _countryFlag!,
          token: _token!,
        );

        // Update SettingsService
        final settingsService = SettingsService();
        settingsService.setAuthToken(_token);
        settingsService.setCountryFlagFromAuth(_countryFlag!);

        // Fetch full profile to ensure we have all data
        await fetchUserProfile();

        notifyListeners();
        return true;
      } else {
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
    _authProvider = null;

    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('auth_token');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userId');
    await prefs.remove('country_flag');
    await prefs.remove('auth_provider');

    // Clear all Hive caches (stats, score, game state, pending results)
    // so a new user doesn't inherit the previous user's data.
    OfflineSyncService.clearAllUserData();

    notifyListeners();
  }

  // Update username — throws Exception with a user-readable message on failure.
  Future<void> updateUsername(String newUsername) async {
    if (_token == null) {
      throw Exception('Not logged in. Please sign in again.');
    }

    try {
      final response = await ApiClient.put('/user/profile', {
        'username': newUsername,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _username = newUsername;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', newUsername);
        notifyListeners();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to update username');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
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

  // Delete account
  Future<bool> deleteAccount({String? password}) async {
    try {
      if (_token == null) {
        print('❌ No auth token available');
        return false;
      }

      final body = isSocialLogin ? <String, dynamic>{} : <String, dynamic>{'password': password ?? ''};
      final response = await ApiClient.delete('/user/profile', body).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        print('✅ Account deleted successfully');
        await logout();
        return true;
      } else {
        final error = json.decode(response.body);
        print('❌ Failed to delete account: ${error['error']}');
        return false;
      }
    } on TimeoutException {
      print('❌ Delete account timeout');
      return false;
    } catch (e) {
      print('❌ Error deleting account: $e');
      return false;
    }
  }
}
