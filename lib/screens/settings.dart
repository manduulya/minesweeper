import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedCountry;
  bool _isLoading = false;
  bool _showPasswordFields = false;

  // List of countries for the dropdown
  final List<String> _countries = [
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'South Korea',
    'Brazil',
    'Mexico',
    'India',
    'China',
    'Russia',
    'Italy',
    'Spain',
    'Netherlands',
    'Sweden',
    'Norway',
    'Denmark',
    'Switzerland',
  ];

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  void _initializeSettings() {
    final authService = context.read<AuthService>();
    final settingsService = context.read<SettingsService>();

    _usernameController.text = authService.username ?? '';
    _selectedCountry = settingsService.userCountry;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      _showErrorSnackBar('Username cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final success = await authService.updateUsername(
        _usernameController.text.trim(),
      );

      if (success) {
        _showSuccessSnackBar('Username updated successfully');
      } else {
        _showErrorSnackBar('Failed to update username');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating username: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateCountry() async {
    if (_selectedCountry == null) {
      _showErrorSnackBar('Please select a country');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsService = context.read<SettingsService>();
      await settingsService.updateUserCountry(_selectedCountry!);
      _showSuccessSnackBar('Country updated successfully');
    } catch (e) {
      _showErrorSnackBar('Error updating country: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all password fields');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showErrorSnackBar('New password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final success = await authService.updatePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (success) {
        _showSuccessSnackBar('Password updated successfully');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _showPasswordFields = false;
        });
      } else {
        _showErrorSnackBar(
          'Failed to update password. Check your current password.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error updating password: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF4E4),
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF0B1E3D),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF0B1E3D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Settings Section
            _buildSectionHeader('Profile Settings'),
            _buildSettingsCard([
              // Username Setting
              _buildSettingsTile(
                icon: Icons.person,
                title: 'Username',
                subtitle: authService.username ?? 'Not set',
                onTap: () => _showUsernameDialog(),
              ),
              Divider(color: Color(0xFF0B1E3D).withOpacity(0.1)),
              // Country Setting
              _buildSettingsTile(
                icon: Icons.flag,
                title: 'Country',
                subtitle: settingsService.userCountry ?? 'Not set',
                trailing: Text(
                  settingsService.getCountryFlag(
                    settingsService.userCountry ?? '',
                  ),
                  style: TextStyle(fontSize: 24),
                ),
                onTap: () => _showCountryDialog(),
              ),
              Divider(color: Color(0xFF0B1E3D).withOpacity(0.1)),
              // Change Password
              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your password',
                onTap: () => _showPasswordDialog(),
              ),
            ]),

            SizedBox(height: 24),

            // Audio Settings Section
            _buildSectionHeader('Audio Settings'),
            _buildSettingsCard([
              // Sound Effects Toggle
              _buildSettingsTile(
                icon: Icons.volume_up,
                title: 'Sound Effects',
                subtitle: 'Game sound effects',
                trailing: Switch(
                  value: settingsService.soundEffectsEnabled,
                  onChanged: (value) {
                    settingsService.setSoundEffects(value);
                  },
                  activeColor: Color(0xFF0B1E3D),
                ),
              ),
              Divider(color: Color(0xFF0B1E3D).withOpacity(0.1)),
              // Background Music Toggle
              _buildSettingsTile(
                icon: Icons.music_note,
                title: 'Background Music',
                subtitle: 'Background music during gameplay',
                trailing: Switch(
                  value: settingsService.backgroundMusicEnabled,
                  onChanged: (value) {
                    settingsService.setBackgroundMusic(value);
                  },
                  activeColor: Color(0xFF0B1E3D),
                ),
              ),
            ]),

            SizedBox(height: 24),

            // // Game Settings Section
            // _buildSectionHeader('Game Settings'),
            // _buildSettingsCard([
            //   // Vibration Toggle
            //   _buildSettingsTile(
            //     icon: Icons.vibration,
            //     title: 'Vibration',
            //     subtitle: 'Haptic feedback',
            //     trailing: Switch(
            //       value: settingsService.vibrationEnabled,
            //       onChanged: (value) {
            //         settingsService.setVibration(value);
            //       },
            //       activeColor: Color(0xFF0B1E3D),
            //     ),
            //   ),
            //   Divider(color: Color(0xFF0B1E3D).withOpacity(0.1)),
            //   // Auto-save Toggle
            //   _buildSettingsTile(
            //     icon: Icons.save,
            //     title: 'Auto-save Progress',
            //     subtitle: 'Automatically save game progress',
            //     trailing: Switch(
            //       value: settingsService.autoSaveEnabled,
            //       onChanged: (value) {
            //         settingsService.setAutoSave(value);
            //       },
            //       activeColor: Color(0xFF0B1E3D),
            //     ),
            //   ),
            // ]),

            // SizedBox(height: 24),

            // Account Actions Section
            _buildSectionHeader('Account'),
            _buildSettingsCard([
              // Logout
              _buildSettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                titleColor: Colors.red,
                onTap: () => _showLogoutDialog(),
              ),
            ]),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Color(0xFF0B1E3D),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF0B1E3D).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: titleColor ?? Color(0xFF0B1E3D), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Color(0xFF0B1E3D),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Color(0xFF0B1E3D).withOpacity(0.6),
          fontSize: 14,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF0B1E3D).withOpacity(0.3),
                  size: 16,
                )
              : null),
      onTap: onTap,
    );
  }

  void _showUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Username'),
        content: TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'New Username',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUsername();
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showCountryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Country'),
        content: DropdownButtonFormField<String>(
          value: _selectedCountry,
          items: _countries
              .map(
                (country) =>
                    DropdownMenuItem(value: country, child: Text(country)),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCountry = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateCountry();
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updatePassword();
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authService = context.read<AuthService>();
              await authService.logout();
              Navigator.pop(context); // Go back to previous screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
