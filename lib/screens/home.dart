import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:country_flags/country_flags.dart';
import 'package:mine_master/managers/responsive_wrapper.dart';
import '../service_utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:mine_master/widgets/click_button_widget.dart';
import '../dialog_utils/displayUsername.dart';
import '../board.dart';
import 'leaderboard.dart';
import 'settings.dart';
import 'landing_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../service_utils/error_handler.dart';
import '../hive/offline_sync_service.dart';
import 'tutorial_screen.dart';

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
    setState(() => _isLoading = true);

    // Capture before any async gaps
    final authService = context.read<AuthService>();

    final online = await OfflineSyncService.isOnline();

    if (online) {
      // Flush any pending offline results BEFORE fetching server stats.
      // Running sync concurrently with a stats fetch caused the server's
      // stale score (pre-sync) to overwrite the locally-cached correct value.
      if (OfflineSyncService.pendingCount > 0) {
        await OfflineSyncService.syncPendingResults();
      }

      try {
        if (!mounted) return;
        await authService.fetchUserProfile();

        final results = await Future.wait([
          _apiService.getUserProfile(),
          _apiService.getUserStats(),
        ]).timeout(const Duration(seconds: 5));

        OfflineSyncService.cacheStats(
          Map<String, dynamic>.from(results[1] as Map),
        );

        if (!mounted) return;
        setState(() {
          userProfile = results[0];
          userStats = results[1];
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString();
        if (msg.contains('401') || msg.contains('403')) {
          _handleLogout();
        } else {
          _loadFromCache();
        }
      }
    } else {
      _loadFromCache();
    }
  }

  void _loadFromCache() {
    final cachedStats = OfflineSyncService.getCachedStats();
    final cachedProfile = OfflineSyncService.getCachedUserProfile();
    setState(() {
      if (cachedProfile != null) userProfile = cachedProfile;
      if (cachedStats != null) userStats = cachedStats;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);

    try {
      final authService = context.read<AuthService>();
      await authService.logout();

      await _apiService.clearToken();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoggingOut = false);
      if (mounted) _errorHandler.handleError(context, e);
    }
  }

  void _showProfileDialog(BuildContext context) {
    if (userProfile == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('Profile'),
            const Spacer(),
            if (userProfile!['country_flag'] != null)
              kIsWeb
                  ? Text(
                      userProfile!['country_flag'].toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B1E3D),
                      ),
                    )
                  : CountryFlag.fromCountryCode(
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
            child: const Text('Close'),
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    await _loadUserData();
  }

  // ✅ NEW: Dark background like loading/landing
  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/background1.webp',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        // gentle dark overlay so content pops
        Container(color: Colors.black.withValues(alpha: 0.25)),
      ],
    );
  }

  // ✅ NEW: Make header readable on dark bg (white + shadow)
  Widget _buildHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ removed beige background, now use loading-style background
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),

          SafeArea(
            child: Column(
              children: [
                // Header
                ResponsiveWrapper(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _isLoading
                              ? _buildHeaderText('Loading...')
                              : GestureDetector(
                                  onTap: () => _showProfileDialog(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: _buildHeaderText(
                                          'Welcome, ${displayUsername(userProfile?['username'])}!',
                                        ),
                                      ),
                                      if (userProfile?['country_flag'] != null &&
                                          userProfile!['country_flag'].toString().isNotEmpty &&
                                          userProfile!['country_flag'].toString() != ApiConstants.kNoCountry) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.50,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: kIsWeb
                                              ? Text(
                                                  userProfile!['country_flag']
                                                      .toString()
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 10,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : CountryFlag.fromCountryCode(
                                                  userProfile!['country_flag']
                                                      .toString()
                                                      .toUpperCase(),
                                                  theme: const ImageTheme(
                                                    height: 20,
                                                    width: 28,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white),
                              onPressed: _isLoading ? null : _navigateToSettings,
                            ),
                            IconButton(
                              icon: _isLoggingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.logout, color: Colors.white),
                              onPressed: _isLoggingOut ? null : _handleLogout,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: ResponsiveWrapper(
                    child: RefreshIndicator(
                      onRefresh: _loadUserData,
                      color: const Color(0xFFFFDD00),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              Image.asset(
                                'assets/appicon.webp',
                                width: 200,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 28),

                              // Stats card (keep light for readability)
                              Card(
                                color: Colors.white,
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: _isLoading
                                      ? const Center(
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
                                                  (userStats?['games_played'] ??
                                                          0)
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
                              const SizedBox(height: 28),

                              // ✅ UPDATED: Play button uses real text + bold + centered
                              ClickButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        final showTutorial =
                                            await TutorialScreen.shouldShow();
                                        if (!mounted) return;
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => showTutorial
                                                ? const TutorialScreen()
                                                : const GameBoard(),
                                          ),
                                        );
                                        await _loadUserData();
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
                                          0xFFFFA200,
                                        ).withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                    color: _isLoading
                                        ? const Color(
                                            0xFF0B1E3D,
                                          ).withValues(alpha: 0.6)
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
                                            'PLAY GAME',
                                            style: TextStyle(
                                              color: Color(0xFFFFDD00),
                                              fontFamily: 'Acsioma',
                                              fontSize: 24,
                                              fontWeight: FontWeight.normal,
                                              letterSpacing: 1,
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
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Secondary buttons
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                                                builder: (_) =>
                                                    const LeaderboardPage(),
                                              ),
                                            );
                                          },
                                  ),
                                  _buildSecondaryButton(
                                    context,
                                    'How to Play',
                                    Icons.help_outline,
                                    _isLoading
                                        ? null
                                        : () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TutorialScreen(
                                                  launchGameOnComplete: false,
                                                ),
                                              ),
                                            ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // ✅ UPDATED: readable description on dark bg
                              Text(
                                'Clear all safe tiles without hitting a mine.\nBuild streaks to earn bonus points.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 14,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0B1E3D),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF0B1E3D).withValues(alpha: 0.7),
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
      icon: Icon(icon, color: const Color(0xFF0B1E3D)),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0B1E3D),
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null
            ? Colors.white
            : Colors.grey.shade300,
        foregroundColor: const Color(0xFF0B1E3D),
        elevation: onPressed != null ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: onPressed != null
                ? const Color(0xFF0B1E3D).withValues(alpha: 0.25)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
