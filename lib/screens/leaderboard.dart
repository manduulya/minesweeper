import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mine_master/managers/responsive_wrapper.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../service_utils/constants.dart';

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
            username: item['username'] as String? ?? '',
            totalScore: (item['total_score'] ?? item['score'] ?? 0) as int,
            countryFlag: item['country_flag'] as String? ?? '',
            level: (item['level'] ?? item['current_level'] ?? item['last_completed_level'] ?? 0) as int,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load leaderboard: $e';
        _isLoading = false;
        _leaderboardData = _getSampleData();
      });
    }
  }

  List<LeaderboardUser> _getSampleData() {
    return [
      LeaderboardUser(username: 'MineExpert',    totalScore: 125400, countryFlag: 'us', level: 12),
      LeaderboardUser(username: 'BombDefuser',   totalScore: 118900, countryFlag: 'ca', level: 11),
      LeaderboardUser(username: 'SafeClicker',   totalScore: 112300, countryFlag: 'uk', level: 10),
      LeaderboardUser(username: 'MineMaster',    totalScore: 108700, countryFlag: 'de', level: 9),
      LeaderboardUser(username: 'FieldExplorer', totalScore: 104200, countryFlag: 'fr', level: 8),
    ];
  }

  bool _hasCountry(String flagCode) =>
      flagCode.isNotEmpty && flagCode != ApiConstants.kNoCountry;

  String _getFlagEmoji(String countryCode) {
    if (!_hasCountry(countryCode)) return '';

    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌍';

    final firstChar = code.codeUnitAt(0);
    final secondChar = code.codeUnitAt(1);

    return String.fromCharCode(0x1F1E6 + (firstChar - 65)) +
        String.fromCharCode(0x1F1E6 + (secondChar - 65));
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                    // Title
                    Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: Color(0xFF0B1E3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),

                    // Refresh button
                    IconButton(
                      icon: Icon(Icons.refresh, color: Color(0xFF0B1E3D)),
                      onPressed: _loadLeaderboardData,
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable content below
            Expanded(
              child: ResponsiveWrapper(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF0B1E3D)),
                            SizedBox(height: 16),
                            Text(
                              'Loading leaderboard...',
                              style: TextStyle(
                                color: Color(0xFF0B1E3D),
                                fontSize: 16,
                              ),
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
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange.shade800,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Using sample data. $_errorMessage',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                      ),
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

                          // Leaderboard table
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
                                : Column(
                                    children: [
                                      _buildTableHeader(),
                                      const Divider(height: 1, thickness: 1, color: Color(0x220B1E3D)),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: _leaderboardData.length,
                                          itemBuilder: (context, index) {
                                            final user = _leaderboardData[index];
                                            return _buildTableRow(
                                              user,
                                              index + 1,
                                              user.username == currentUsername,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
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

  String _formatScore(int score) => score.toString();

  Widget _buildTableHeader() {
    const style = TextStyle(
      color: Color(0xFF0B1E3D),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
    return Container(
      color: const Color(0xFF0B1E3D).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text('Rank',   style: style, textAlign: TextAlign.center)),
          SizedBox(width: 32),
          Expanded(           child: Text('Player', style: style)),
          SizedBox(width: 52, child: Text('Lvl',    style: style, textAlign: TextAlign.center)),
          SizedBox(width: 88, child: Text('Score',  style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildTableRow(LeaderboardUser user, int rank, bool isCurrentUser) {
    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF0B1E3D).withValues(alpha: 0.07)
            : null,
        border: isCurrentUser
            ? const Border(
                left: BorderSide(color: Color(0xFF0B1E3D), width: 3),
              )
            : const Border(
                bottom: BorderSide(color: Color(0x11000000), width: 1),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(width: 44, child: Center(child: _getRankIcon(rank))),
          // Flag
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                _getFlagEmoji(user.countryFlag),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          // Player
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    user.username.isEmpty
                        ? ''
                        : '${user.username[0].toUpperCase()}${user.username.substring(1)}',
                    style: TextStyle(
                      color: const Color(0xFF0B1E3D),
                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1E3D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'YOU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Level
          SizedBox(
            width: 52,
            child: Text(
              '${user.level}',
              style: TextStyle(
                color: const Color(0xFF0B1E3D).withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Score
          SizedBox(
            width: 88,
            child: Text(
              '${user.totalScore} pts',
              style: const TextStyle(
                color: Color(0xFF0B1E3D),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardUser {
  final String username;
  final int totalScore;
  final String countryFlag;
  final int level;

  LeaderboardUser({
    required this.username,
    required this.totalScore,
    required this.countryFlag,
    this.level = 0,
  });
}
