import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mine_master/managers/responsive_wrapper.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../service_utils/country_data.dart';
import '../service_utils/constants.dart';
import '../service_utils/error_handler.dart';
import 'tutorial_screen.dart';

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
  final TextEditingController _countrySearchController =
      TextEditingController();
  final TextEditingController _deleteAccountPasswordController =
      TextEditingController();

  String? _selectedCountryFlagCode;
  List<CountryData> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = CountryHelper.getCountriesSorted();
    _initializeSettings();
  }

  void _initializeSettings() {
    final authService = context.read<AuthService>();
    final settingsService = context.read<SettingsService>();

    _usernameController.text = authService.username ?? '';
    _selectedCountryFlagCode = settingsService.userCountryFlagCode;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _countrySearchController.dispose();
    _deleteAccountPasswordController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = CountryHelper.getCountriesSorted();
      } else {
        _filteredCountries = CountryHelper.getCountriesSorted()
            .where(
              (country) =>
                  country.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      _showErrorSnackBar('Username cannot be empty');
      return;
    }

    try {
      final authService = context.read<AuthService>();
      await authService.updateUsername(_usernameController.text.trim());
      _showSuccessSnackBar('Username updated successfully');
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showErrorSnackBar(msg);
    }
  }

  Future<void> _updateCountry() async {
    if (_selectedCountryFlagCode == null) {
      _showErrorSnackBar('Please select a country');
      return;
    }

    try {
      final settingsService = context.read<SettingsService>();
      final authService = context.read<AuthService>();

      final success = await settingsService.updateUserCountry(
        _selectedCountryFlagCode!,
      );

      if (success) {
        // Refresh the auth service to update the flag everywhere
        await authService.fetchUserProfile();
        _showSuccessSnackBar('Country updated successfully');
      } else {
        _showErrorSnackBar('Failed to update country. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating country: $e');
    }
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
      } else {
        _showErrorSnackBar(
          'Failed to update password. Check your current password.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error updating password: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ErrorHandler().showSuccess(context, message);
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
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header at top
            ResponsiveWrapper(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Color(0xFF0B1E3D)),
                      onPressed: () async {
                        // Refresh profile before going back
                        final authService = context.read<AuthService>();
                        await authService.fetchUserProfile();
                        Navigator.of(context).pop();
                      },
                    ),

                    // Title
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Color(0xFF0B1E3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),

                    // Spacer to balance the back button
                    SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Scrollable content below
            Expanded(
              child: ResponsiveWrapper(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Settings Section
                      _buildSectionHeader('Profile Settings'),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.person,
                          title: 'Username',
                          subtitle: authService.username ?? 'Not set',
                          onTap: () => _showUsernameDialog(),
                        ),
                        Divider(color: Color(0xFF0B1E3D).withValues(alpha: .1)),
                        _buildSettingsTile(
                          icon: Icons.flag,
                          title: 'Country',
                          subtitle:
                              (settingsService.userCountryFlagCode == null ||
                                  settingsService.userCountryFlagCode ==
                                      ApiConstants.kNoCountry ||
                                  settingsService.userCountryFlagCode!.isEmpty)
                              ? 'Not set'
                              : settingsService.userCountry ?? 'Not set',
                          trailing:
                              (settingsService.userCountryFlagCode != null &&
                                  settingsService.userCountryFlagCode !=
                                      ApiConstants.kNoCountry &&
                                  settingsService
                                      .userCountryFlagCode!
                                      .isNotEmpty)
                              ? Text(
                                  settingsService.getCountryFlag(
                                    settingsService.userCountryFlagCode!,
                                  ),
                                  style: TextStyle(fontSize: 24),
                                )
                              : null,
                          onTap: () => _showCountryDialog(),
                        ),
                        Divider(color: Color(0xFF0B1E3D).withValues(alpha: .1)),
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
                        _buildSettingsTile(
                          icon: Icons.volume_up,
                          title: 'Sound Effects',
                          subtitle: 'Game sound effects',
                          trailing: Switch(
                            value: settingsService.soundEffectsEnabled,
                            onChanged: (value) =>
                                settingsService.setSoundEffects(value),
                            activeColor: Color(0xFF0B1E3D),
                          ),
                        ),
                        Divider(color: Color(0xFF0B1E3D).withValues(alpha: .1)),
                        _buildSettingsTile(
                          icon: Icons.music_note,
                          title: 'Vibration',
                          subtitle: 'Haptic feedback during gameplay',
                          trailing: Switch(
                            value: settingsService.vibrationEnabled,
                            onChanged: (value) =>
                                settingsService.setVibration(value),
                            activeColor: Color(0xFF0B1E3D),
                          ),
                        ),
                      ]),

                      SizedBox(height: 24),

                      // Help Section
                      _buildSectionHeader('Help'),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.school_outlined,
                          title: 'How to Play',
                          subtitle: 'Replay the tutorial',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TutorialScreen(
                                launchGameOnComplete: false,
                              ),
                            ),
                          ),
                        ),
                      ]),

                      SizedBox(height: 24),

                      // Account Actions Section
                      _buildSectionHeader('Account'),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.logout,
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          titleColor: Colors.red,
                          onTap: () => _showLogoutDialog(),
                        ),
                        Divider(color: Color(0xFF0B1E3D).withValues(alpha: .1)),
                        _buildSettingsTile(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account',
                          titleColor: Colors.red,
                          onTap: () => _showDeleteAccountDialog(),
                        ),
                      ]),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
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
            color: Colors.black.withValues(alpha: .05),
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
          color: Color(0xFF0B1E3D).withValues(alpha: .1),
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
          color: Color(0xFF0B1E3D).withValues(alpha: .6),
          fontSize: 14,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF0B1E3D).withValues(alpha: .3),
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
    final settingsService = context.read<SettingsService>();

    // Reset search and filtered list
    _countrySearchController.clear();
    _filteredCountries = CountryHelper.getCountriesSorted();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select Country'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _countrySearchController,
                  decoration: InputDecoration(
                    hintText: 'Search countries...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _filterCountries(value);
                    });
                  },
                ),
                SizedBox(height: 12),
                // Countries list
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected =
                          _selectedCountryFlagCode == country.flagCode;

                      return ListTile(
                        leading: Text(
                          settingsService.getCountryFlag(country.flagCode),
                          style: TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          country.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Color(0xFF0B1E3D))
                            : null,
                        selected: isSelected,
                        selectedTileColor: Color(
                          0xFF0B1E3D,
                        ).withValues(alpha: .05),
                        onTap: () {
                          setState(() {
                            _selectedCountryFlagCode = country.flagCode;
                          });
                          Navigator.pop(context);
                          _updateCountry();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _countrySearchController.clear();
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        ),
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
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final authService = context.read<AuthService>();
    final isSocial = authService.isSocialLogin;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
            if (!isSocial) ...[
              SizedBox(height: 16),
              Text(
                'Enter your password to confirm:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _deleteAccountPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccountPasswordController.clear();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final authService = context.read<AuthService>();
    if (!authService.isSocialLogin && _deleteAccountPasswordController.text.isEmpty) {
      _showErrorSnackBar('Please enter your password');
      return;
    }

    try {
      final success = await authService.deleteAccount(
        password: authService.isSocialLogin ? null : _deleteAccountPasswordController.text,
      );

      if (success) {
        _showSuccessSnackBar('Account deleted successfully');
        _deleteAccountPasswordController.clear();
        Navigator.pop(context);
      } else {
        _showErrorSnackBar('Failed to delete account. Check your password.');
        _deleteAccountPasswordController.clear();
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting account: $e');
      _deleteAccountPasswordController.clear();
    }
  }
}
