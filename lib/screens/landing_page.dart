import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import 'package:provider/provider.dart';
import 'sign_up.dart';
import '../services/api_service.dart';
import '../service_utils/error_handler.dart';
import '../main.dart';
import '../services/auth_service.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class UserNotFoundException implements Exception {
  final String message;
  UserNotFoundException([this.message = 'User not found']);
}

class _LandingPageState extends State<LandingPage> {
  final TextEditingController _usernameController =
      TextEditingController(); // Changed from email to username
  final TextEditingController _passwordController = TextEditingController();

  // Server integration
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();
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
        // Valid profile → go to game
        _navigateToGame();
      } else {
        print('Empty profile received, staying on login page');
      }
    } on UserNotFoundException {
      print('User not found, staying on login page');
      // maybe navigate to login/registration explicitly
      // Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Auth check failed: $e');
      // stay on login page
    }
  }

  void _navigateToGame() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => SplashToAuthWrapper()));
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
    } on AccountNotFoundException {
      _errorHandler.showError(context, 'Account not found. Please sign up.');
    } on WrongPasswordException {
      _errorHandler.showError(context, 'Incorrect password. Try again.');
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
    if (_usernameController.text.isEmpty) {
      _errorHandler.showError(
        context,
        'Please enter your username to reset password',
      );
      return;
    }

    // Show dialog for now (you can implement password reset later)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password Reset'),
        content: Text(
          'Password reset functionality will be implemented soon.\n\n'
          'For now, please contact support if you need to reset your password for username: ${_usernameController.text}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      body: SafeArea(
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

                  // Username input field (changed from email)
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
                        hintText: 'Username', // Changed from Email
                        hintStyle: TextStyle(
                          color: const Color(0xFF0B1E3D).withValues(alpha: 0.6),
                        ),
                        prefixIcon: const Icon(
                          Icons.person, // Changed from email icon
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
                      obscureText: true,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(
                          color: const Color(0xFF0B1E3D).withValues(alpha: 0.6),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
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
    );
  }
}
