import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../service_utils/error_handler.dart';
import '../exceptions/app_exceptions.dart'; // Import centralized exceptions

class ForgotPasswordDialog extends StatefulWidget {
  final String? initialUsername;

  const ForgotPasswordDialog({super.key, this.initialUsername});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();

  bool _isLoading = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null) {
      _usernameController.text = widget.initialUsername!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call API to reset password
      await _apiService.resetPassword(
        username: _usernameController.text.trim().toLowerCase(),
        email: _emailController.text.trim().toLowerCase(),
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      _errorHandler.showSuccess(
        context,
        'Password reset successful! You can now login with your new password.',
      );

      Navigator.of(context).pop(true); // Return true to indicate success
    } on UserNotFoundException {
      _errorHandler.showError(
        context,
        'No account found with this username and email combination.',
      );
    } on ServerTimeoutException {
      _errorHandler.showError(
        context,
        'Server took too long to respond. Please try again.',
      );
    } on NetworkException {
      _errorHandler.showError(
        context,
        'Network error. Please check your connection.',
      );
    } catch (error) {
      _errorHandler.handleError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFCF4E4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Reset Password',
                        style: TextStyle(
                          color: Color(0xFF0B1E3D),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFF0B1E3D)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your username and email to reset your password',
                  style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Username field
                _buildInputField(
                  controller: _usernameController,
                  label: 'Username',
                  icon: Icons.person,
                  validator: _validateUsername,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Email field
                _buildInputField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email,
                  validator: _validateEmail,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // New password field
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  validator: _validateNewPassword,
                  isVisible: _newPasswordVisible,
                  onToggleVisibility: () {
                    setState(() {
                      _newPasswordVisible = !_newPasswordVisible;
                    });
                  },
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Confirm password field
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  validator: _validateConfirmPassword,
                  isVisible: _confirmPasswordVisible,
                  onToggleVisibility: () {
                    setState(() {
                      _confirmPasswordVisible = !_confirmPasswordVisible;
                    });
                  },
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),

                // Reset button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleResetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1E3D),
                    foregroundColor: const Color(0xFFFFDD00),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color(0xFFFFA200),
                        width: 2,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFDD00),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'RESET PASSWORD',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required bool enabled,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF0B1E3D)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: const Color(0xFF0B1E3D).withValues(alpha: 0.7),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF0B1E3D)),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA21212)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA21212)),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required bool enabled,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: !isVisible,
      enabled: enabled,
      style: const TextStyle(color: Color(0xFF0B1E3D)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: const Color(0xFF0B1E3D).withValues(alpha: 0.7),
        ),
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF0B1E3D)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF0B1E3D),
          ),
          onPressed: enabled ? onToggleVisibility : null,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA21212)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA21212)),
        ),
      ),
    );
  }
}
