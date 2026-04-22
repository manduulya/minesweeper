// lib/utils/constants.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConstants {
  // Development URLs
  static const String localAndroidEmulator = 'http://10.0.2.2:3000/api';
  static const String localiOSSimulator = 'http://localhost:3000/api';
  static const String localPhysicalDevice =
      'http://10.0.0.83:3000/api'; // Your machine's LAN IP — update if it changes

  // Production URL
  static const String production =
      'https://mine-master-server-production.up.railway.app/api';

  /// Automatically resolves to the right URL:
  /// - Release build → production server
  /// - Debug/profile on iOS/web → localhost (simulator)
  /// - Debug/profile on Android → LAN IP (physical device or set to 10.0.2.2 for emulator)
  static String get baseUrl {
    if (kReleaseMode) return production;
    if (kIsWeb || Platform.isIOS) return localiOSSimulator;
    return localPhysicalDevice;
  }

  // Other constants
  static const Duration requestTimeout = Duration(seconds: 5);
  static const String tokenKey = 'jwt_token';

  // Country constants
  static const String kNoCountry = 'international';

  // Game constants
  static const Map<String, Map<String, int>> gameDifficulties = {
    'beginner': {'width': 9, 'height': 9, 'mines': 10},
    'intermediate': {'width': 16, 'height': 16, 'mines': 40},
    'expert': {'width': 30, 'height': 16, 'mines': 99},
  };
}
