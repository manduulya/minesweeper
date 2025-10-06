import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  final String _currentUserCountry = 'United States';

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  // Simulate loading leaderboard data (replace with actual API call)
  Future<void> _loadLeaderboardData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(Duration(seconds: 1));

    // Sample leaderboard data (replace with actual data from your backend)
    final sampleData = [
      LeaderboardUser(
        username: 'MineExpert',
        totalScore: 125400,
        country: 'United States',
      ),
      LeaderboardUser(
        username: 'BombDefuser',
        totalScore: 118900,
        country: 'Canada',
      ),
      LeaderboardUser(
        username: 'SafeClicker',
        totalScore: 112300,
        country: 'United Kingdom',
      ),
      LeaderboardUser(
        username: 'MineMaster',
        totalScore: 108700,
        country: 'Germany',
      ),
      LeaderboardUser(
        username: 'FieldExplorer',
        totalScore: 104200,
        country: 'France',
      ),
      LeaderboardUser(
        username: 'TileHunter',
        totalScore: 99800,
        country: 'Japan',
      ),
      LeaderboardUser(
        username: 'BoomAvoider',
        totalScore: 95400,
        country: 'Australia',
      ),
      LeaderboardUser(
        username: 'NumberCruncher',
        totalScore: 91200,
        country: 'Netherlands',
      ),
      LeaderboardUser(
        username: 'PatternSeeker',
        totalScore: 87600,
        country: 'Sweden',
      ),
      LeaderboardUser(
        username: 'LogicMaster',
        totalScore: 84300,
        country: 'South Korea',
      ),
      LeaderboardUser(
        username: 'QuickSolver',
        totalScore: 80900,
        country: 'Brazil',
      ),
      LeaderboardUser(
        username: 'ClearPath',
        totalScore: 77500,
        country: 'Italy',
      ),
      LeaderboardUser(
        username: 'SafeZone',
        totalScore: 74100,
        country: 'Spain',
      ),
      LeaderboardUser(
        username: 'MineDetector',
        totalScore: 70800,
        country: 'Russia',
      ),
      LeaderboardUser(
        username: 'TileExpert',
        totalScore: 67200,
        country: 'Mexico',
      ),
    ];

    setState(() {
      _leaderboardData = sampleData;
      _isLoading = false;
    });
  }

  // Get country flag emoji (simplified version)
  String _getCountryFlag(String country) {
    final flagMap = {
      'United States': '🇺🇸',
      'Canada': '🇨🇦',
      'United Kingdom': '🇬🇧',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Japan': '🇯🇵',
      'Australia': '🇦🇺',
      'Netherlands': '🇳🇱',
      'Sweden': '🇸🇪',
      'South Korea': '🇰🇷',
      'Brazil': '🇧🇷',
      'Italy': '🇮🇹',
      'Spain': '🇪🇸',
      'Russia': '🇷🇺',
      'Mexico': '🇲🇽',
      'China': '🇨🇳',
      'India': '🇮🇳',
      'Norway': '🇳🇴',
      'Denmark': '🇩🇰',
      'Switzerland': '🇨🇭',
    };
    return flagMap[country] ?? '🌍';
  }

  // Get rank color based on position
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

  // Get rank icon for top 3
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
                // Header stats
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _leaderboardData.length,
                    itemBuilder: (context, index) {
                      final user = _leaderboardData[index];
                      final rank = index + 1;
                      final isCurrentUser = user.username == currentUsername;

                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Color(0xFF0B1E3D).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrentUser
                              ? Border.all(color: Color(0xFF0B1E3D), width: 2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                                  ? _getRankColor(rank).withOpacity(0.1)
                                  : Color(0xFF0B1E3D).withOpacity(0.1),
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
                                    borderRadius: BorderRadius.circular(12),
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
                            user.country,
                            style: TextStyle(
                              color: Color(0xFF0B1E3D).withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getCountryFlag(user.country),
                                style: TextStyle(fontSize: 24),
                              ),
                              SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
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
                                      color: Color(0xFF0B1E3D).withOpacity(0.6),
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
            color: Color(0xFF0B1E3D).withOpacity(0.7),
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
  final String country;

  LeaderboardUser({
    required this.username,
    required this.totalScore,
    required this.country,
  });
}
