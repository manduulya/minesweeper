import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import 'landing_page.dart';
// Add these imports
import '../services/api_service.dart';
import '../service_utils/error_handler.dart';
import '../service_utils/country_data.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _retypePasswordController =
      TextEditingController();

  // Server integration
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();

  String? _selectedCountryName;
  String? _selectedCountryFlag;
  bool _isRegistering = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _retypePasswordController.text.isEmpty ||
        _selectedCountryFlag == null) {
      _errorHandler.showError(context, 'Please fill in all fields');
      return false;
    }

    if (_passwordController.text.length < 6) {
      _errorHandler.showError(
        context,
        'Password must be at least 6 characters long',
      );
      return false;
    }

    if (_passwordController.text != _retypePasswordController.text) {
      _errorHandler.showError(context, 'Passwords do not match');
      return false;
    }

    // Basic email validation
    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      _errorHandler.showError(context, 'Please enter a valid email address');
      return false;
    }

    // Username validation
    if (_usernameController.text.length < 3) {
      _errorHandler.showError(
        context,
        'Username must be at least 3 characters long',
      );
      return false;
    }

    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateInputs()) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      final result = await _apiService.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedCountryFlag!,
      );

      // Registration successful
      _errorHandler.showSuccess(
        context,
        'Registration successful! Welcome ${result['user']['username']}!',
      );

      // Navigate to main game or landing page
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LandingPage()));
    } catch (error) {
      _errorHandler.handleError(context, error);
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  Widget _buildCountryAutocomplete() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Autocomplete<CountryData>(
        displayStringForOption: (CountryData option) => option.name,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<CountryData>.empty();
          }
          return CountryHelper.countries.where(
            (country) => country.name.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            ),
          );
        },
        onSelected: (CountryData selection) {
          setState(() {
            _selectedCountryName = selection.name;
            _selectedCountryFlag = selection.flagCode;
          });
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
              // Keep the controller synced with selected country
              if (_selectedCountryName != null &&
                  textEditingController.text != _selectedCountryName) {
                textEditingController.text = _selectedCountryName!;
              }

              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  prefixIcon: _selectedCountryFlag != null
                      ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            CountryHelper.getFlagEmoji(_selectedCountryFlag!),
                            style: const TextStyle(fontSize: 20),
                          ),
                        )
                      : const Icon(Icons.public, color: Color(0xFF0B1E3D)),
                  hintText: 'Select Country',
                  hintStyle: TextStyle(
                    color: const Color(0xFF0B1E3D).withOpacity(0.6),
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
                    borderSide: const BorderSide(color: Color(0xFF0B1E3D)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(color: Color(0xFF0B1E3D)),
              );
            },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              CountryHelper.getFlagEmoji(option.flagCode),
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.name,
                                style: const TextStyle(
                                  color: Color(0xFF0B1E3D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🧭 Entered SignUpPage');
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
                  const SizedBox(height: 40),

                  // SIGN UP heading
                  Stack(
                    children: [
                      // Stroke
                      Text(
                        'SIGN UP',
                        style: TextStyle(
                          fontFamily: 'Acsioma',
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = const Color(0xFF707070),
                        ),
                      ),
                      // Fill
                      const Text(
                        'SIGN UP',
                        style: TextStyle(
                          fontFamily: 'Acsioma',
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFFFFDD00),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Username input field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: TextStyle(
                          color: const Color(0xFF0B1E3D).withOpacity(0.6),
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Color(0xFF0B1E3D),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFF0B1E3D).withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFF0B1E3D).withOpacity(0.3),
                          ),
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

                  // Email address input field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(
                          color: const Color(0xFF0B1E3D).withOpacity(0.6),
                        ),
                        prefixIcon: const Icon(
                          Icons.email,
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
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(
                          color: const Color(0xFF0B1E3D).withOpacity(0.6),
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

                  // Re-type Password input field (Fixed controller)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller:
                          _retypePasswordController, // Fixed: was using wrong controller
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Re-type Password',
                        hintStyle: TextStyle(
                          color: const Color(0xFF0B1E3D).withOpacity(0.6),
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

                  // Country selection with flags
                  _buildCountryAutocomplete(),

                  const SizedBox(height: 32),

                  // REGISTER button
                  ClickButton(
                    onPressed: _isRegistering ? null : _handleRegister,
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
                            color: const Color(0xFF00F6FF).withOpacity(0.7),
                            blurRadius: 11,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        color: const Color(0xFF0B1E3D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFA200),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: _isRegistering
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFDD00),
                                ),
                              )
                            : const Text(
                                'REGISTER',
                                style: TextStyle(
                                  color: Color(0xFFFFDD00),
                                  fontFamily: 'Acsioma',
                                  fontSize: 24,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: Color(0xFF0B1E3D),
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LandingPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Login',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
