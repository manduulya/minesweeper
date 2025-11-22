import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../service_utils/country_data.dart';
import '../service_utils/constants.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // API Configuration
  final String _baseUrl = ApiConstants.baseUrl;
  String? _authToken;

  // Settings state
  bool _soundEffectsEnabled = true;
  bool _backgroundMusicEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoSaveEnabled = true;
  String? _userCountryFlagCode; // Store flag code instead of country name

  // Getters
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  bool get backgroundMusicEnabled => _backgroundMusicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get autoSaveEnabled => _autoSaveEnabled;
  String? get userCountryFlagCode => _userCountryFlagCode;

  // Get country name from flag code
  String? get userCountry {
    if (_userCountryFlagCode == null) return null;
    final country = CountryHelper.getCountryByFlagCode(_userCountryFlagCode!);
    return country?.name;
  }

  // Set auth token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Initialize settings from storage
  Future<void> initializeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _soundEffectsEnabled = prefs.getBool('soundEffectsEnabled') ?? true;
      _backgroundMusicEnabled = prefs.getBool('backgroundMusicEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _autoSaveEnabled = prefs.getBool('autoSaveEnabled') ?? true;
      _userCountryFlagCode = prefs.getString('userCountryFlagCode');
      _authToken = prefs.getString('auth_token');

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing settings: $e');
    }
  }

  // Sound Effects setting
  Future<void> setSoundEffects(bool enabled) async {
    _soundEffectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEffectsEnabled', enabled);
    notifyListeners();
  }

  // Background Music setting
  Future<void> setBackgroundMusic(bool enabled) async {
    _backgroundMusicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundMusicEnabled', enabled);
    notifyListeners();
  }

  // Vibration setting
  Future<void> setVibration(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationEnabled', enabled);
    notifyListeners();
  }

  // Auto-save setting
  Future<void> setAutoSave(bool enabled) async {
    _autoSaveEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSaveEnabled', enabled);
    notifyListeners();
  }

  // Set country flag from auth (internal use)
  void setCountryFlagFromAuth(String flagCode) {
    _userCountryFlagCode = flagCode;
    // Also save to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userCountryFlagCode', flagCode);
    });
    notifyListeners();
  }

  // Update user country (sends to API and saves locally)
  Future<bool> updateUserCountry(String flagCode) async {
    try {
      if (_authToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({'country_flag': flagCode}),
      );

      if (response.statusCode == 200) {
        _userCountryFlagCode = flagCode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userCountryFlagCode', flagCode);

        // Also update AuthService to keep them in sync
        notifyListeners();
        return true;
      } else {
        print('❌ Failed to update country: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating country: $e');
      return false;
    }
  }

  // Get country flag emoji from flag code
  String getCountryFlag(String flagCode) {
    if (flagCode.isEmpty || flagCode == 'international') {
      return '🌍';
    }

    // Convert ISO code to flag emoji
    // Each flag emoji is composed of regional indicator symbols
    final upperCode = flagCode.toUpperCase();
    if (upperCode.length != 2) return '🌍';

    final first = String.fromCharCode(0x1F1E6 + upperCode.codeUnitAt(0) - 65);
    final second = String.fromCharCode(0x1F1E6 + upperCode.codeUnitAt(1) - 65);
    return first + second;
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _soundEffectsEnabled = true;
    _backgroundMusicEnabled = true;
    _vibrationEnabled = true;
    _autoSaveEnabled = true;
    _userCountryFlagCode = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('soundEffectsEnabled');
    await prefs.remove('backgroundMusicEnabled');
    await prefs.remove('vibrationEnabled');
    await prefs.remove('autoSaveEnabled');
    await prefs.remove('userCountryFlagCode');

    notifyListeners();
  }
}
