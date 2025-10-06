import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import '../board.dart';
import 'leaderboard.dart';
import 'settings.dart';
import 'landing_page.dart';
import '../services/api_service.dart';
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
      // Clear the stored token
      await _apiService.clearToken();

      // Navigate back to landing page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );
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
              Text(
                _getFlagEmoji(userProfile!['country_flag']),
                style: TextStyle(fontSize: 24),
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

  String _getFlagEmoji(String flagCode) {
    const flagMap = {
      'international': '🌍',
      'us': '🇺🇸',
      'uk': '🇬🇧',
      'ca': '🇨🇦',
      'au': '🇦🇺',
      'de': '🇩🇪',
      'fr': '🇫🇷',
      'it': '🇮🇹',
      'es': '🇪🇸',
      'jp': '🇯🇵',
      'kr': '🇰🇷',
      'cn': '🇨🇳',
      'in': '🇮🇳',
      'br': '🇧🇷',
      'mx': '🇲🇽',
      'ru': '🇷🇺',
      'za': '🇿🇦',
      'eg': '🇪🇬',
      'ng': '🇳🇬',
      'ar': '🇦🇷',
      'cl': '🇨🇱',
      'pe': '🇵🇪',
      'se': '🇸🇪',
      'no': '🇳🇴',
      'dk': '🇩🇰',
      'fi': '🇫🇮',
      'nl': '🇳🇱',
      'be': '🇧🇪',
      'ch': '🇨🇭',
      'at': '🇦🇹',
      'pt': '🇵🇹',
      'ie': '🇮🇪',
      'pl': '🇵🇱',
      'cz': '🇨🇿',
      'hu': '🇭🇺',
      'gr': '🇬🇷',
      'tr': '🇹🇷',
      'il': '🇮🇱',
      'ae': '🇦🇪',
      'sa': '🇸🇦',
      'th': '🇹🇭',
      'vn': '🇻🇳',
      'id': '🇮🇩',
      'my': '🇲🇾',
      'sg': '🇸🇬',
      'ph': '🇵🇭',
    };
    return flagMap[flagCode] ?? '🌍';
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

  @override
  Widget build(BuildContext context) {
    print('🧭 Entered HomeScreen');

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
                      Text(
                        _getFlagEmoji(userProfile!['country_flag']),
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ],
                ),
              ),
        actions: [
          // Profile button
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.person, color: Color(0xFF0B1E3D)),
              onPressed: () => _showProfileDialog(context),
            ),
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
        child: Center(
          child: SingleChildScrollView(
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
                                // Text(
                                //   'Player Statistics',
                                //   style: TextStyle(
                                //     color: Color(0xFF0B1E3D),
                                //     fontSize: 18,
                                //     fontWeight: FontWeight.bold,
                                //   ),
                                // ),
                                // const SizedBox(height: 16),
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
                  ClickButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GameBoard(),
                              ),
                            );
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
                            color: const Color(0xFF00F6FF).withOpacity(0.7),
                            blurRadius: 11,
                            offset: const Offset(0, 0),
                          ),
                        ],
                        color: _isLoading
                            ? Color(0xFF0B1E3D).withOpacity(0.6)
                            : Color(0xFF0B1E3D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isLoading
                              ? Color(0xFFFFA200).withOpacity(0.6)
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
                        _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsPage(),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Refresh button
                  TextButton.icon(
                    onPressed: _isLoading ? null : _loadUserData,
                    icon: Icon(
                      Icons.refresh,
                      color: Color(0xFF0B1E3D),
                      size: 16,
                    ),
                    label: Text(
                      'Refresh Stats',
                      style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Game description
                  Text(
                    'Clear all safe tiles without hitting a mine. Build streaks to earn bonus points.',
                    style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
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
            color: Color(0xFF0B1E3D).withOpacity(0.7),
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
                ? Color(0xFF0B1E3D).withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
