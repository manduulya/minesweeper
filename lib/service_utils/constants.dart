// lib/utils/constants.dart
class ApiConstants {
  // Development URLs
  static const String localAndroidEmulator = 'http://10.0.2.2:3000/api';
  static const String localiOSSimulator = 'http://localhost:3000/api';
  static const String localPhysicalDevice =
      'http://192.168.1.100:3000/api'; // Replace with your computer's IP

  // Production URL
  static const String production = 'https://your-domain.com/api';

  // Current environment - change this based on your setup
  static const String baseUrl = localAndroidEmulator; // Change as needed

  // Other constants
  static const Duration requestTimeout = Duration(seconds: 30);
  static const String tokenKey = 'jwt_token';

  // Game constants
  static const Map<String, Map<String, int>> gameDifficulties = {
    'beginner': {'width': 9, 'height': 9, 'mines': 10},
    'intermediate': {'width': 16, 'height': 16, 'mines': 40},
    'expert': {'width': 30, 'height': 16, 'mines': 99},
  };
}
