import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Settings state
  bool _soundEffectsEnabled = true;
  bool _backgroundMusicEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoSaveEnabled = true;
  String? _userCountry;

  // Getters
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  bool get backgroundMusicEnabled => _backgroundMusicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get autoSaveEnabled => _autoSaveEnabled;
  String? get userCountry => _userCountry;

  // Initialize settings from storage
  Future<void> initializeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _soundEffectsEnabled = prefs.getBool('soundEffectsEnabled') ?? true;
      _backgroundMusicEnabled = prefs.getBool('backgroundMusicEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _autoSaveEnabled = prefs.getBool('autoSaveEnabled') ?? true;
      _userCountry = prefs.getString('userCountry');

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

  // Update user country
  Future<void> updateUserCountry(String country) async {
    _userCountry = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userCountry', country);
    notifyListeners();
  }

  // Get country flag emoji
  String getCountryFlag(String country) {
    final flagMap = {
      'United States': '🇺🇸',
      'Canada': '🇨🇦',
      'United Kingdom': '🇬🇧',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Japan': '🇯🇵',
      'Australia': '🇦🇺',
      'Netherlands': '🇳🇱',
      'Sweden': '🇸🇪',
      'South Korea': '🇰🇷',
      'Brazil': '🇧🇷',
      'Italy': '🇮🇹',
      'Spain': '🇪🇸',
      'Russia': '🇷🇺',
      'Mexico': '🇲🇽',
      'China': '🇨🇳',
      'India': '🇮🇳',
      'Norway': '🇳🇴',
      'Denmark': '🇩🇰',
      'Switzerland': '🇨🇭',
    };
    return flagMap[country] ?? '🌍';
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _soundEffectsEnabled = true;
    _backgroundMusicEnabled = true;
    _vibrationEnabled = true;
    _autoSaveEnabled = true;
    _userCountry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('soundEffectsEnabled');
    await prefs.remove('backgroundMusicEnabled');
    await prefs.remove('vibrationEnabled');
    await prefs.remove('autoSaveEnabled');
    await prefs.remove('userCountry');

    notifyListeners();
  }
}
