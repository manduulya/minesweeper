// lib/utils/constants.dart
class ApiConstants {
  // Development URLs
  static const String localAndroidEmulator = 'http://10.0.2.2:3000/api';
  static const String localiOSSimulator = 'http://localhost:3000/api';
  static const String localPhysicalDevice =
      'http://10.0.0.83:3000/api'; // Replace with your computer's IP

  // Production URL
  static const String production =
      'https://mine-master-server-production.up.railway.app/api';

  // Current environment - change this based on your setup
  static const String baseUrl =
      localiOSSimulator; // use machine IP for physical Android device

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
