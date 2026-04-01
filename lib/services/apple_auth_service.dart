import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthService {
  Future<Map<String, dynamic>> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final nameParts = [
      credential.givenName,
      credential.familyName,
    ].where((s) => s != null && s.isNotEmpty).join(' ');

    return {
      'apple_id': credential.userIdentifier,
      'name': nameParts.isNotEmpty ? nameParts : null,
      'email': credential.email,
      'identity_token': credential.identityToken,
      'authorization_code': credential.authorizationCode,
    };
  }
}
