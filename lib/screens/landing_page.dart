import 'package:flutter/material.dart';
import 'package:mine_master/widgets/click_button_widget.dart';
import '../managers/responsive_wrapper.dart';
import 'package:provider/provider.dart';
import 'sign_up.dart';
import '../dialog_utils/forgot_password.dart';
import '../services/api_service.dart';
import '../service_utils/error_handler.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../exceptions/app_exceptions.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../services/facebook_auth_service.dart';
import '../services/apple_auth_service.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FacebookAuthService _facebookAuthService = FacebookAuthService();
  final AppleAuthService _appleAuthService = AppleAuthService();
  bool _isFacebookLoading = false;
  bool _isAppleLoading = false;

  // Server integration
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSocialLogin({
    required Future<void> Function() authFn,
    required Future<Map<String, dynamic>> Function() apiFn,
    required void Function(bool) setLoading,
  }) async {
    final authService = context.read<AuthService>();
    setLoading(true);
    try {
      await authFn();
      final result = await apiFn();
      if (!mounted) return;
      await authService.setUserData(
        result['user']['username'],
        result['token'],
        email: result['user']['email'],
        userId: result['user']['id']?.toString(),
        countryFlag: result['user']['country_flag'],
      );
      _errorHandler.showSuccess(context, 'Welcome, ${result['user']['username']}!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashToAuthWrapper()),
      );
    } catch (error) {
      if (mounted) _errorHandler.handleError(context, error);
    } finally {
      if (mounted) setLoading(false);
    }
  }

  Future<void> _handleAppleLogin() async {
    Map<String, dynamic>? appleData;
    await _handleSocialLogin(
      authFn: () async {
        appleData = await _appleAuthService.signInWithApple();
      },
      apiFn: () => _apiService.loginWithApple(
        appleId: appleData!['apple_id'],
        name: appleData!['name'],
        email: appleData!['email'],
        identityToken: appleData!['identity_token'],
      ),
      setLoading: (v) => setState(() => _isAppleLoading = v),
    );
  }

  Future<void> _handleFacebookLogin() async {
    Map<String, dynamic>? fbData;
    await _handleSocialLogin(
      authFn: () async {
        fbData = await _facebookAuthService.signInWithFacebook();
      },
      apiFn: () => _apiService.loginWithFacebook(
        facebookId: fbData!['facebook_id'],
        name: fbData!['name'],
        email: fbData!['email'],
      ),
      setLoading: (v) => setState(() => _isFacebookLoading = v),
    );
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _errorHandler.showError(context, 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.login(
        _usernameController.text.trim().toLowerCase(),
        _passwordController.text,
      );

      _errorHandler.showSuccess(
        context,
        'Welcome back, ${authService.username}!',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashToAuthWrapper()),
      );
    } on WrongPasswordException {
      _errorHandler.showError(context, 'Incorrect password. Try again.');
    } on AccountNotFoundException {
      _errorHandler.showError(context, 'Account not found. Please sign up.');
    } on ServerTimeoutException {
      _errorHandler.showError(
        context,
        'Server took too long. Try again later.',
      );
    } on UnknownLoginException {
      _errorHandler.showError(context, 'Login failed. Please try again.');
    } catch (error) {
      _errorHandler.handleError(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (context) => ForgotPasswordDialog(
        initialUsername:
            _usernameController.text.trim().toLowerCase().isNotEmpty
            ? _usernameController.text.trim().toLowerCase()
            : null,
      ),
    );

    if (result == true && mounted) {
      _passwordController.clear();
    }
  }

  // ✅ Title widget with glow/shadow so it’s readable on dark background
  Widget _buildTitle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'Welcome to',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            height: 0.9, // 👈 tighten line box
            color: Colors.white,
            fontFamily: 'Agatha',
            shadows: [
              Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
              Shadow(
                color: Color(0xFF00F6FF),
                blurRadius: 30,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
        Text(
          'MINE MASTER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            height: 0.9,
            letterSpacing: 2,
            color: Color(0xFFFFDD00),
            fontFamily: 'Acsioma',
            shadows: [
              Shadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 3)),
              Shadow(
                color: Color(0xFFFFA200),
                blurRadius: 22,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required bool isLoading,
    required Future<void> Function()? onPressed,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return ClickButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Container(
        width: 132,
        height: 48,
        decoration: BoxDecoration(
          color: onPressed == null
              ? backgroundColor.withValues(alpha: 0.6)
              : backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: isLoading
              ? CircularProgressIndicator(color: iconColor, strokeWidth: 2)
              : Icon(icon, color: iconColor, size: 28),
        ),
      ),
    );
  }

  Widget _buildLoginContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTitle(),
        const SizedBox(height: 18),

        // Logo
        Image.asset('assets/appicon.png', width: 180, fit: BoxFit.contain),
        const SizedBox(height: 30),

        // Username field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _usernameController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Username',
              hintStyle: TextStyle(
                color: const Color(0xFF0B1E3D).withValues(alpha: 0.55),
              ),
              prefixIcon: const Icon(Icons.person, color: Color(0xFF0B1E3D)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(color: Color(0xFF0B1E3D)),
          ),
        ),

        const SizedBox(height: 12),

        // Password field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(
                color: const Color(0xFF0B1E3D).withValues(alpha: 0.55),
              ),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF0B1E3D)),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF0B1E3D),
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(color: Color(0xFF0B1E3D)),
          ),
        ),

        const SizedBox(height: 10),

        // Forgot password (make it readable on dark bg)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            child: Text(
              'Forgot password?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                decoration: TextDecoration.underline,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Login button
        ClickButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: Container(
            width: 280,
            height: 48,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFA200).withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
              color: _isLoading
                  ? const Color(0xFF0B1E3D).withValues(alpha: 0.6)
                  : const Color(0xFF0B1E3D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : const Text(
                      'LOGIN',
                      style: TextStyle(
                        color: Color(0xFFFFDD00),
                        fontFamily: 'Acsioma',
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // On iOS: two icon-only buttons side by side
        // On other platforms: full-width Facebook button with text
        if (defaultTargetPlatform == TargetPlatform.iOS)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton(
                icon: Icons.facebook,
                isLoading: _isFacebookLoading,
                onPressed: (_isLoading || _isFacebookLoading || _isAppleLoading)
                    ? null
                    : _handleFacebookLogin,
                backgroundColor: const Color(0xFF1877F2),
                iconColor: Colors.white,
              ),
              const SizedBox(width: 16),
              _buildSocialButton(
                icon: Icons.apple,
                isLoading: _isAppleLoading,
                onPressed: (_isLoading || _isFacebookLoading || _isAppleLoading)
                    ? null
                    : _handleAppleLogin,
                backgroundColor: Colors.white,
                iconColor: Colors.black,
              ),
            ],
          )
        else
          ClickButton(
            onPressed: (_isLoading || _isFacebookLoading)
                ? null
                : _handleFacebookLogin,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: Container(
              width: 280,
              height: 48,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFA200).withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ],
                color: (_isLoading || _isFacebookLoading)
                    ? const Color(0xFF0B1E3D).withValues(alpha: 0.6)
                    : const Color(0xFF0B1E3D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isFacebookLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.facebook,
                            color: Color(0xFFFFDD00),
                            size: 26,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'LOGIN WITH FACEBOOK',
                            style: TextStyle(
                              color: Color(0xFFFFDD00),
                              fontFamily: 'Acsioma',
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Sign up',
                style: TextStyle(
                  color: Color(0xFFFFDD00),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Text(
          'Clear all safe tiles without hitting a mine.\nBuild streaks to earn bonus points.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 10,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background1.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // Keep it, but don’t crush the background too much
          Container(color: Colors.black.withValues(alpha: 0.25)),

          SafeArea(
            child: ResponsiveWrapper(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildLoginContent(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
