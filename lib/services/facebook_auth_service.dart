import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class FacebookAuthService {
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  Future<Map<String, dynamic>> signInWithFacebook() async {
    print('📘 [FB Auth] Starting Facebook sign-in...');

    try {
      // Trigger Facebook login
      print('📘 [FB Auth] Triggering Facebook login dialog...');
      final LoginResult result = await _facebookAuth.login(
        permissions: ['email', 'public_profile'],
      );

      print('📘 [FB Auth] Login result status: ${result.status}');

      // Check login status
      if (result.status == LoginStatus.success) {
        print('✅ [FB Auth] Login successful!');

        // Get access token
        final AccessToken accessToken = result.accessToken!;
        print(
          '📘 [FB Auth] Access token received: ${accessToken.tokenString.substring(0, 20)}...',
        );

        // Get user data from Facebook
        print('📘 [FB Auth] Fetching user data from Facebook...');
        final userData = await _facebookAuth.getUserData(
          fields: "id,name,email",
        );

        print('✅ [FB Auth] User data received:');
        print('  - Facebook ID: ${userData['id']}');
        print('  - Name: ${userData['name']}');
        print('  - Email: ${userData['email'] ?? 'NO EMAIL'}');

        final userdataResult = {
          'facebook_id': userData['id'],
          'name': userData['name'],
          'email': userData['email'] ?? '',
          'access_token': accessToken.tokenString,
        };

        print('📘 [FB Auth] Returning user data to app');
        return userdataResult;
      } else if (result.status == LoginStatus.cancelled) {
        print('⚠️ [FB Auth] User cancelled login');
        throw Exception('Facebook login cancelled by user');
      } else {
        print('❌ [FB Auth] Login failed: ${result.message}');
        throw Exception('Facebook login failed: ${result.message}');
      }
    } catch (e) {
      print('❌ [FB Auth] Exception: $e');
      throw Exception('Facebook authentication error: $e');
    }
  }

  /// Sign out from Facebook
  Future<void> signOut() async {
    try {
      await _facebookAuth.logOut();
    } catch (e) {
      print('Facebook sign out error: $e');
    }
  }

  /// Check if user is currently logged in with Facebook
  Future<bool> isLoggedIn() async {
    try {
      final accessToken = await _facebookAuth.accessToken;
      return accessToken != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current Facebook user data (if logged in)
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final accessToken = await _facebookAuth.accessToken;
      if (accessToken == null) return null;

      final userData = await _facebookAuth.getUserData(fields: "id,name,email");

      return {
        'facebook_id': userData['id'],
        'name': userData['name'],
        'email': userData['email'] ?? '',
      };
    } catch (e) {
      return null;
    }
  }
}
