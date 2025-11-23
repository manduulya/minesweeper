import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:provider/provider.dart';
import '../board.dart';
import 'leaderboard.dart';
import 'settings.dart';
import 'landing_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../service_utils/error_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Server integration
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();

  // User data
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? userStats;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch fresh profile from AuthService
      final authService = context.read<AuthService>();
      await authService.fetchUserProfile();

      // Then fetch profile and stats from API
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getUserStats(),
      ]);

      setState(() {
        userProfile = results[0];
        userStats = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (e.toString().contains('401') || e.toString().contains('403')) {
        _handleLogout();
      } else {
        _errorHandler.handleError(context, e);
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Logout from AuthService
      final authService = context.read<AuthService>();
      await authService.logout();

      // Clear the stored token
      await _apiService.clearToken();

      // Navigate back to landing page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoggingOut = false;
      });
      _errorHandler.handleError(context, e);
    }
  }

  void _showProfileDialog(BuildContext context) {
    if (userProfile == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text('Profile'),
            const Spacer(),
            if (userProfile!['country_flag'] != null)
              CountryFlag.fromCountryCode(
                userProfile!['country_flag'].toString().toUpperCase(),
                theme: const ImageTheme(height: 24, width: 32),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${userProfile!['username'] ?? 'Unknown'}'),
            Text('Email: ${userProfile!['email'] ?? 'Unknown'}'),
            Text('Auth Method: ${userProfile!['auth_method'] ?? 'Unknown'}'),
            Text('Member Since: ${_formatDate(userProfile!['created_at'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _navigateToSettings() async {
    // Navigate to settings and wait for it to close
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));

    // Refresh user data after returning from settings
    print('🔄 Returned from settings, refreshing profile...');
    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF4E4),
        elevation: 0,
        title: _isLoading
            ? Text(
                'Loading...',
                style: TextStyle(
                  color: Color(0xFF0B1E3D),
                  fontWeight: FontWeight.bold,
                ),
              )
            : GestureDetector(
                onTap: () => _showProfileDialog(context),
                child: Row(
                  children: [
                    Text(
                      'Welcome, ${userProfile?['username'] ?? 'Player'}!',
                      style: TextStyle(
                        color: Color(0xFF0B1E3D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userProfile?['country_flag'] != null) ...[
                      SizedBox(width: 8),
                      CountryFlag.fromCountryCode(
                        userProfile!['country_flag'].toString().toUpperCase(),
                        theme: const ImageTheme(height: 20, width: 28),
                      ),
                    ],
                  ],
                ),
              ),
        actions: [
          // Logout button
          IconButton(
            icon: _isLoggingOut
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0B1E3D),
                      ),
                    ),
                  )
                : Icon(Icons.logout, color: Color(0xFF0B1E3D)),
            onPressed: _isLoggingOut ? null : _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          color: Color(0xFF0B1E3D),
          child: Center(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Game logo
                    Image.asset(
                      'assets/landingPageLogo.png',
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // Player stats card
                    Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0B1E3D),
                                ),
                              )
                            : Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        'Games Played',
                                        (userStats?['games_played'] ?? 0)
                                            .toString(),
                                      ),
                                      _buildStatItem(
                                        'Games Won',
                                        '${userStats?['games_won'] ?? 0}',
                                      ),
                                      _buildStatItem(
                                        'Total Score',
                                        '${userStats?['total_score'] ?? 0}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Play button
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const GameBoard(),
                                ),
                              );
                              // Refresh stats after game ends
                              await _loadUserData();
                              return;
                            },
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
                              ).withValues(alpha: .7),
                              blurRadius: 11,
                              offset: const Offset(0, 0),
                            ),
                          ],
                          color: _isLoading
                              ? Color(0xFF0B1E3D).withValues(alpha: .6)
                              : Color(0xFF0B1E3D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isLoading
                                ? Color(0xFFFFA200).withValues(alpha: .6)
                                : Color(0xFFFFA200),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'PLAY GAME',
                            style: TextStyle(
                              color: Color(0xFFFFDD00),
                              fontFamily: 'Acsioma',
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Additional buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSecondaryButton(
                          context,
                          'Leaderboard',
                          Icons.leaderboard,
                          _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LeaderboardPage(),
                                    ),
                                  );
                                },
                        ),
                        _buildSecondaryButton(
                          context,
                          'Settings',
                          Icons.settings,
                          _isLoading ? null : _navigateToSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Game description
                    Text(
                      'Clear all safe tiles without hitting a mine. Build streaks to earn bonus points.',
                      style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Color(0xFF0B1E3D),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF0B1E3D).withValues(alpha: .7),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Color(0xFF0B1E3D)),
      label: Text(label, style: TextStyle(color: Color(0xFF0B1E3D))),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null
            ? Colors.white
            : Colors.grey.shade300,
        foregroundColor: Color(0xFF0B1E3D),
        elevation: onPressed != null ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: onPressed != null
                ? Color(0xFF0B1E3D).withValues(alpha: .3)
                : Colors.grey.withValues(alpha: .3),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
