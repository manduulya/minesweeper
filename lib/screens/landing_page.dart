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
import '../services/facebook_auth_service.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FacebookAuthService _facebookAuthService = FacebookAuthService();
  bool _isFacebookLoading = false;

  // Server integration
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingAuth() async {
    try {
      final profile = await _apiService.getUserProfile();

      if (profile.isNotEmpty) {
        _navigateToGame();
      } else {
        print('Empty profile received, staying on login page');
      }
    } on UserNotFoundException {
      print('User not found, staying on login page');
    } catch (e) {
      print('Auth check failed: $e');
    }
  }

  void _navigateToGame() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => SplashToAuthWrapper()));
  }

  Future<void> _handleFacebookLogin() async {
    print('🟦 [Landing Page] Facebook login button pressed');

    setState(() {
      _isFacebookLoading = true;
    });

    try {
      print('🟦 [Landing Page] Calling Facebook auth service...');
      final facebookData = await _facebookAuthService.signInWithFacebook();
      print('✅ [Landing Page] Got Facebook data, calling API...');

      final result = await _apiService.loginWithFacebook(
        facebookId: facebookData['facebook_id'],
        name: facebookData['name'],
        email: facebookData['email'],
      );
      print('✅ [Landing Page] API call successful');

      if (!mounted) {
        print('⚠️ [Landing Page] Widget unmounted, aborting');
        return;
      }

      print('🟦 [Landing Page] Updating auth service...');
      final authService = context.read<AuthService>();
      await authService.setUserData(
        result['user']['username'],
        result['token'],
        email: result['user']['email'],
        userId: result['user']['id']?.toString(),
        countryFlag: result['user']['country_flag'],
      );
      print('✅ [Landing Page] Auth service updated');

      _errorHandler.showSuccess(
        context,
        'Welcome, ${result['user']['username']}!',
      );

      print('🟦 [Landing Page] Navigating to game...');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashToAuthWrapper()),
      );
      print('✅ [Landing Page] Navigation complete');
    } catch (error) {
      print('❌ [Landing Page] Error occurred: $error');
      print('❌ [Landing Page] Error type: ${error.runtimeType}');
      print('❌ [Landing Page] Stack trace: ${StackTrace.current}');

      if (mounted) {
        _errorHandler.handleError(context, error);
      }
    } finally {
      if (mounted) {
        print('🟦 [Landing Page] Setting loading to false');
        setState(() {
          _isFacebookLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _errorHandler.showError(context, 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      await authService.login(
        _usernameController.text.trim(),
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
      // Handle wrong password first (more specific)
      _errorHandler.showError(context, 'Incorrect password. Try again.');
    } on AccountNotFoundException {
      // Then handle account not found
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleForgotPassword() async {
    // Show the forgot password dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (context) => ForgotPasswordDialog(
        initialUsername: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : null,
      ),
    );

    // If password was reset successfully, clear the password field
    if (result == true && mounted) {
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Welcome title
                    Image.asset(
                      'assets/WelcomeTitle.png',
                      width: 300,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),

                    // Minesweeper logo
                    Image.asset(
                      'assets/landingPageLogo.png',
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // Username input field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Username',
                          hintStyle: TextStyle(
                            color: const Color(
                              0xFF0B1E3D,
                            ).withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF0B1E3D),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0B1E3D),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFF0B1E3D)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Password input field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
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
                            color: const Color(
                              0xFF0B1E3D,
                            ).withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF0B1E3D),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF0B1E3D),
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0B1E3D),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFF0B1E3D)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Color(0xFF0B1E3D),
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                        height: 56,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00F6FF,
                              ).withValues(alpha: 0.7),
                              blurRadius: 11,
                              offset: const Offset(0, 0),
                            ),
                          ],
                          color: _isLoading
                              ? const Color(0xFF0B1E3D).withValues(alpha: 0.6)
                              : const Color(0xFF0B1E3D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isLoading
                                ? const Color(0xFFFFA200).withValues(alpha: 0.6)
                                : const Color(0xFFFFA200),
                            width: 3,
                          ),
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                        height: 56,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1877F2,
                              ).withValues(alpha: 0.6), // Facebook blue glow
                              blurRadius: 11,
                              offset: const Offset(0, 0),
                            ),
                          ],
                          color: (_isLoading || _isFacebookLoading)
                              ? const Color(0xFF0B1E3D).withValues(alpha: 0.6)
                              : const Color(0xFF0B1E3D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_isLoading || _isFacebookLoading)
                                ? const Color(0xFF1877F2).withValues(alpha: 0.6)
                                : const Color(0xFF1877F2),
                            width: 3,
                          ),
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign up text with link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Color(0xFF0B1E3D),
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpPage(),
                                    ),
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
                              color: Color(0xFFA21212),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Game description
                    const Text(
                      'Clear all safe tiles without hitting a mine. Build streaks to earn bonus points.',
                      style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
