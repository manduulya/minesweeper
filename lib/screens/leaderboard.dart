import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../service_utils/country_data.dart'; // Import your country data utility

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.getLeaderboard(limit: 50);

      setState(() {
        _leaderboardData = data.map((item) {
          return LeaderboardUser(
            username: item['username'] as String,
            totalScore: item['total_score'] as int,
            countryFlag: item['country_flag'] as String, // Store the flag code
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load leaderboard: $e';
        _isLoading = false;
        // Use sample data as fallback for demo purposes
        _leaderboardData = _getSampleData();
      });
    }
  }

  // Sample data as fallback
  List<LeaderboardUser> _getSampleData() {
    return [
      LeaderboardUser(
        username: 'MineExpert',
        totalScore: 125400,
        countryFlag: 'us',
      ),
      LeaderboardUser(
        username: 'BombDefuser',
        totalScore: 118900,
        countryFlag: 'ca',
      ),
      LeaderboardUser(
        username: 'SafeClicker',
        totalScore: 112300,
        countryFlag: 'uk',
      ),
      LeaderboardUser(
        username: 'MineMaster',
        totalScore: 108700,
        countryFlag: 'de',
      ),
      LeaderboardUser(
        username: 'FieldExplorer',
        totalScore: 104200,
        countryFlag: 'fr',
      ),
    ];
  }

  // Get country name from flag code using your country_data.dart
  String _getCountryName(String flagCode) {
    final country = CountryHelper.getCountryByFlagCode(flagCode);
    return country?.name ?? 'International';
  }

  // Get country flag widget from flag code
  // Note: Since you're using the country_flags package, you'll use CountryFlag widget
  // For the leaderboard list item, we'll return the flag code to use with CountryFlag widget
  String _getCountryFlagCode(String flagCode) {
    final country = CountryHelper.getCountryByFlagCode(flagCode);
    return country?.flagCode ?? 'international';
  }

  // Convert country code to flag emoji
  String _getFlagEmoji(String countryCode) {
    if (countryCode == 'international') return '🌍';

    // Convert ISO country code to flag emoji
    // Each flag emoji is composed of two regional indicator symbols
    // A = 🇦 (U+1F1E6), B = 🇧 (U+1F1E7), etc.
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌍';

    final firstChar = code.codeUnitAt(0);
    final secondChar = code.codeUnitAt(1);

    // Regional indicator symbols start at U+1F1E6 (🇦)
    // A is 65 in ASCII, so we calculate: 0x1F1E6 + (char - 65)
    return String.fromCharCode(0x1F1E6 + (firstChar - 65)) +
        String.fromCharCode(0x1F1E6 + (secondChar - 65));
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Color(0xFFFFD700); // Gold
      case 2:
        return Color(0xFFC0C0C0); // Silver
      case 3:
        return Color(0xFFCD7F32); // Bronze
      default:
        return Color(0xFF0B1E3D); // Default navy
    }
  }

  Widget _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24);
      case 2:
        return Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 22);
      case 3:
        return Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 20);
      default:
        return SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                color: Color(0xFF0B1E3D),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUsername = authService.username ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF4E4),
        elevation: 0,
        title: Text(
          'Leaderboard',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF0B1E3D)),
            onPressed: _loadLeaderboardData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0B1E3D)),
                  SizedBox(height: 16),
                  Text(
                    'Loading leaderboard...',
                    style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Error message if any
                if (_errorMessage != null)
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade800),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Using sample data. $_errorMessage',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Header stats
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Total Players',
                        '${_leaderboardData.length}',
                      ),
                      _buildStatCard(
                        'Your Rank',
                        _getCurrentUserRank(currentUsername),
                      ),
                      _buildStatCard('Top Score', _getTopScore()),
                    ],
                  ),
                ),

                // Leaderboard list
                Expanded(
                  child: _leaderboardData.isEmpty
                      ? Center(
                          child: Text(
                            'No leaderboard data available',
                            style: TextStyle(
                              color: Color(0xFF0B1E3D),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _leaderboardData.length,
                          itemBuilder: (context, index) {
                            final user = _leaderboardData[index];
                            final rank = index + 1;
                            final isCurrentUser =
                                user.username == currentUsername;

                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? Color(0xFF0B1E3D).withValues(alpha: .1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrentUser
                                    ? Border.all(
                                        color: Color(0xFF0B1E3D),
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .05),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: rank <= 3
                                        ? _getRankColor(
                                            rank,
                                          ).withValues(alpha: .1)
                                        : Color(
                                            0xFF0B1E3D,
                                          ).withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(child: _getRankIcon(rank)),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user.username,
                                        style: TextStyle(
                                          color: Color(0xFF0B1E3D),
                                          fontWeight: isCurrentUser
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (isCurrentUser)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF0B1E3D),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  _getCountryName(user.countryFlag),
                                  style: TextStyle(
                                    color: Color(
                                      0xFF0B1E3D,
                                    ).withValues(alpha: .7),
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Display country flag emoji
                                    // If you want to use the country_flags package widget instead:
                                    // CountryFlag.fromCountryCode(
                                    //   user.countryFlag,
                                    //   height: 24,
                                    //   width: 32,
                                    // ),
                                    Text(
                                      _getFlagEmoji(user.countryFlag),
                                      style: TextStyle(fontSize: 24),
                                    ),
                                    SizedBox(width: 12),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatScore(user.totalScore),
                                          style: TextStyle(
                                            color: Color(0xFF0B1E3D),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'points',
                                          style: TextStyle(
                                            color: Color(
                                              0xFF0B1E3D,
                                            ).withValues(alpha: .6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value) {
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
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Color(0xFF0B1E3D).withValues(alpha: .7),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getCurrentUserRank(String username) {
    final index = _leaderboardData.indexWhere(
      (user) => user.username == username,
    );
    return index != -1 ? '#${index + 1}' : 'N/A';
  }

  String _getTopScore() {
    if (_leaderboardData.isEmpty) return '0';
    return _formatScore(_leaderboardData.first.totalScore);
  }

  String _formatScore(int score) {
    if (score >= 1000000) {
      return '${(score / 1000000).toStringAsFixed(1)}M';
    } else if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}K';
    }
    return score.toString();
  }
}

class LeaderboardUser {
  final String username;
  final int totalScore;
  final String countryFlag; // Store the flag code (e.g., 'us', 'uk', 'ca')

  LeaderboardUser({
    required this.username,
    required this.totalScore,
    required this.countryFlag,
  });
}
