// Add these dependencies to your pubspec.yaml:
/*
dependencies:
  flutter_facebook_auth: ^6.0.3
  google_sign_in: ^6.1.5
  http: ^1.1.0
  url_launcher: ^6.2.1
*/

import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String baseUrl = 'http://your-server:3000/api';

  // Traditional Login
  Future<Map<String, dynamic>> traditionalLogin(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error']);
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Traditional Register
  Future<Map<String, dynamic>> traditionalRegister({
    required String username,
    required String email,
    required String password,
    String countryFlag = 'international',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'country_flag': countryFlag,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error']);
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Facebook Login
  Future<Map<String, dynamic>> facebookLogin() async {
    try {
      // Trigger Facebook login
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // Get user data from Facebook
        final userData = await FacebookAuth.instance.getUserData();

        // Check if user exists in your database
        final response = await http.get(
          Uri.parse(
            '$baseUrl/auth/oauth/status/facebook?oauth_id=${userData['id']}',
          ),
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          // User doesn't exist, redirect to web OAuth flow
          throw Exception('Please complete Facebook signup via web');
        }
      } else {
        throw Exception('Facebook login failed');
      }
    } catch (e) {
      throw Exception('Facebook login error: $e');
    }
  }

  // Google Sign-In
  Future<Map<String, dynamic>> googleLogin() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        // Check if user exists in your database
        final response = await http.get(
          Uri.parse(
            '$baseUrl/auth/oauth/status/google?oauth_id=${googleUser.id}',
          ),
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          // User doesn't exist, redirect to web OAuth flow
          throw Exception('Please complete Google signup via web');
        }
      } else {
        throw Exception('Google sign-in cancelled');
      }
    } catch (e) {
      throw Exception('Google login error: $e');
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mine Master Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Traditional Login Form
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),

            // Traditional Login Button
            ElevatedButton(
              onPressed: _isLoading ? null : _traditionalLogin,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Login'),
            ),
            SizedBox(height: 16),

            Text('OR', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),

            // Facebook Login Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _facebookLogin,
              icon: Icon(Icons.facebook, color: Colors.white),
              label: Text('Continue with Facebook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1877F2),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            SizedBox(height: 12),

            // Google Login Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _googleLogin,
              icon: Image.asset(
                'assets/google_logo.png',
                height: 18,
              ), // Add Google logo asset
              label: Text('Continue with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                minimumSize: Size(double.infinity, 48),
              ),
            ),
            SizedBox(height: 24),

            // Sign Up Link
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: Text('Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _traditionalLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.traditionalLogin(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Save token and user data
      await _saveAuthData(result['token'], result['user']);

      // Navigate to main app
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _facebookLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.facebookLogin();

      // Save token and user data
      await _saveAuthData(result['token'], result['user']);

      // Navigate to main app
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (e.toString().contains('complete Facebook signup via web')) {
        // Open web OAuth flow
        await _openWebOAuth('facebook');
      } else {
        _showError(e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.googleLogin();

      // Save token and user data
      await _saveAuthData(result['token'], result['user']);

      // Navigate to main app
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (e.toString().contains('complete Google signup via web')) {
        // Open web OAuth flow
        await _openWebOAuth('google');
      } else {
        _showError(e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openWebOAuth(String provider) async {
    // This will open the web browser for OAuth
    final url = '${AuthService.baseUrl}/auth/$provider';

    // You can use url_launcher or webview
    // await launch(url);

    // Or show a dialog explaining the process
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete Sign Up'),
        content: Text(
          'Please visit our website to complete the $provider sign up process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    // Save to SharedPreferences or secure storage
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.setString('auth_token', token);
    // await prefs.setString('user_data', jsonEncode(user));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Registration Screen Example
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _selectedFlag = 'international';
  bool _isLoading = false;

  final List<Map<String, String>> _flags = [
    {'code': 'international', 'name': 'International'},
    {'code': 'us', 'name': 'United States'},
    {'code': 'uk', 'name': 'United Kingdom'},
    {'code': 'ca', 'name': 'Canada'},
    {'code': 'au', 'name': 'Australia'},
    {'code': 'de', 'name': 'Germany'},
    {'code': 'fr', 'name': 'France'},
    {'code': 'jp', 'name': 'Japan'},
    // Add more countries as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Account')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Country Flag Dropdown
            DropdownButtonFormField<String>(
              value: _selectedFlag,
              decoration: InputDecoration(
                labelText: 'Country Flag',
                border: OutlineInputBorder(),
              ),
              items: _flags
                  .map(
                    (flag) => DropdownMenuItem(
                      value: flag['code'],
                      child: Text(flag['name']!),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedFlag = value!),
            ),
            SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Create Account'),
            ),
            SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Already have an account? Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    // Validation
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.traditionalRegister(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        countryFlag: _selectedFlag,
      );

      // Save auth data
      await _saveAuthData(result['token'], result['user']);

      // Navigate to main app
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    // Implement secure storage here
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
