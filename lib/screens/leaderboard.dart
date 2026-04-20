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

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  // ── Career ─────────────────────────────────────────────────────────────────
  List<LeaderboardUser> _careerData = [];
  bool _isLoadingCareer = true;
  String? _careerError;

  // ── World Map ──────────────────────────────────────────────────────────────
  List<WorldMapLeaderboardUser> _worldMapData = [];
  bool _isLoadingWorldMap = true;
  String? _worldMapError;

  late final TabController _tabController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCareerData();
    _loadWorldMapData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadCareerData() async {
    setState(() { _isLoadingCareer = true; _careerError = null; });
    try {
      final data = await _apiService.getLeaderboard(limit: 50);
      setState(() {
        _careerData = data.map((item) => LeaderboardUser(
          username:   item['username']    as String? ?? '',
          totalScore: (item['total_score'] ?? item['score'] ?? 0) as int,
          countryFlag: item['country_flag'] as String? ?? '',
          level:      (item['level'] ?? item['current_level'] ??
                       item['last_completed_level'] ?? 0) as int,
        )).toList();
        _isLoadingCareer = false;
      });
    } catch (e) {
      setState(() {
        _careerError  = e.toString();
        _careerData   = _sampleCareerData();
        _isLoadingCareer = false;
      });
    }
  }

  Future<void> _loadWorldMapData() async {
    setState(() { _isLoadingWorldMap = true; _worldMapError = null; });
    try {
      final data = await _apiService.getWorldMapLeaderboard(limit: 50);
      setState(() {
        _worldMapData = data.map((item) => WorldMapLeaderboardUser(
          username:          item['username']          as String? ?? '',
          countryFlag:       item['country_flag']      as String? ?? '',
          countriesRevealed: (item['countries_revealed'] ?? 0) as int,
        )).toList();
        _isLoadingWorldMap = false;
      });
    } catch (e) {
      setState(() {
        _worldMapError    = e.toString();
        _worldMapData     = [];
        _isLoadingWorldMap = false;
      });
    }
  }

  void _refreshAll() {
    _loadCareerData();
    _loadWorldMapData();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<LeaderboardUser> _sampleCareerData() => [
    LeaderboardUser(username: 'MineExpert',    totalScore: 125400, countryFlag: 'us', level: 12),
    LeaderboardUser(username: 'BombDefuser',   totalScore: 118900, countryFlag: 'ca', level: 11),
    LeaderboardUser(username: 'SafeClicker',   totalScore: 112300, countryFlag: 'uk', level: 10),
    LeaderboardUser(username: 'MineMaster',    totalScore: 108700, countryFlag: 'de', level: 9),
    LeaderboardUser(username: 'FieldExplorer', totalScore: 104200, countryFlag: 'fr', level: 8),
  ];

  bool _hasCountry(String flagCode) =>
      flagCode.isNotEmpty && flagCode != ApiConstants.kNoCountry;

  String _getFlagEmoji(String countryCode) {
    if (!_hasCountry(countryCode)) return '';
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌍';
    return String.fromCharCode(0x1F1E6 + (code.codeUnitAt(0) - 65)) +
           String.fromCharCode(0x1F1E6 + (code.codeUnitAt(1) - 65));
  }

  Widget _rankIcon(int rank) {
    switch (rank) {
      case 1: return const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24);
      case 2: return const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 22);
      case 3: return const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 20);
      default:
        return SizedBox(width: 24, height: 24,
          child: Center(child: Text('$rank',
            style: const TextStyle(color: Color(0xFF0B1E3D),
                fontWeight: FontWeight.bold, fontSize: 14))));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUsername =
        context.watch<AuthService>().username ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            ResponsiveWrapper(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF0B1E3D)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text('Leaderboard',
                      style: TextStyle(color: Color(0xFF0B1E3D),
                          fontWeight: FontWeight.bold, fontSize: 24)),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF0B1E3D)),
                      onPressed: _refreshAll,
                    ),
                  ],
                ),
              ),
            ),

            // Tab bar
            ResponsiveWrapper(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1E3D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF0B1E3D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF0B1E3D),
                  labelStyle: const TextStyle(
                    fontFamily: 'Acsioma',
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Acsioma',
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                  tabs: const [
                    Tab(text: 'CAREER'),
                    Tab(text: 'WORLD MAP'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCareerTab(currentUsername),
                  _buildWorldMapTab(currentUsername),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Career tab ─────────────────────────────────────────────────────────────

  Widget _buildCareerTab(String currentUsername) {
    if (_isLoadingCareer) return _loadingView();

    return ResponsiveWrapper(
      child: Column(
        children: [
          if (_careerError != null) _errorBanner('Using sample data.'),

          // Stats strip
          _statsStrip([
            _statCard('Players',   '${_careerData.length}'),
            _statCard('Your Rank', _careerRank(currentUsername)),
            _statCard('Top Score', _careerData.isEmpty ? '0'
                : '${_careerData.first.totalScore}'),
          ]),

          // Table
          Expanded(
            child: _careerData.isEmpty
                ? _emptyView()
                : Column(children: [
                    _careerHeader(),
                    const Divider(height: 1, thickness: 1, color: Color(0x220B1E3D)),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _careerData.length,
                        itemBuilder: (_, i) => _careerRow(
                          _careerData[i], i + 1,
                          _careerData[i].username == currentUsername),
                      ),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }

  String _careerRank(String username) {
    final i = _careerData.indexWhere((u) => u.username == username);
    return i != -1 ? '#${i + 1}' : 'N/A';
  }

  Widget _careerHeader() {
    const style = TextStyle(color: Color(0xFF0B1E3D), fontSize: 11,
        fontWeight: FontWeight.bold, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFF0B1E3D).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const SizedBox(width: 44, child: Text('Rank',   style: style, textAlign: TextAlign.center)),
        const SizedBox(width: 32),
        const Expanded(           child: Text('Player', style: style)),
        const SizedBox(width: 52, child: Text('Lvl',    style: style, textAlign: TextAlign.center)),
        const SizedBox(width: 88, child: Text('Score',  style: style, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _careerRow(LeaderboardUser user, int rank, bool isMe) {
    return Container(
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF0B1E3D).withValues(alpha: 0.07) : null,
        border: isMe
            ? const Border(left: BorderSide(color: Color(0xFF0B1E3D), width: 3))
            : const Border(bottom: BorderSide(color: Color(0x11000000), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        SizedBox(width: 44, child: Center(child: _rankIcon(rank))),
        SizedBox(width: 32, child: Center(
          child: Text(_getFlagEmoji(user.countryFlag),
              style: const TextStyle(fontSize: 16)))),
        Expanded(child: _usernameCell(user.username, isMe)),
        SizedBox(width: 52, child: Text('${user.level}',
          style: TextStyle(color: const Color(0xFF0B1E3D).withValues(alpha: 0.65),
              fontSize: 12, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center)),
        SizedBox(width: 88, child: Text('${user.totalScore} pts',
          style: const TextStyle(color: Color(0xFF0B1E3D),
              fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.right)),
      ]),
    );
  }

  // ── World Map tab ──────────────────────────────────────────────────────────

  Widget _buildWorldMapTab(String currentUsername) {
    if (_isLoadingWorldMap) return _loadingView();

    return ResponsiveWrapper(
      child: Column(
        children: [
          if (_worldMapError != null) _errorBanner('Could not load world map leaderboard.'),

          // Stats strip
          _statsStrip([
            _statCard('Explorers',  '${_worldMapData.length}'),
            _statCard('Your Rank',  _worldMapRank(currentUsername)),
            _statCard('Top Explorer', _worldMapData.isEmpty ? '0'
                : '${_worldMapData.first.countriesRevealed} 🌍'),
          ]),

          // Table
          Expanded(
            child: _worldMapData.isEmpty
                ? _emptyView(message: 'No explorers yet.\nReveal a country to appear here!')
                : Column(children: [
                    _worldMapHeader(),
                    const Divider(height: 1, thickness: 1, color: Color(0x220B1E3D)),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _worldMapData.length,
                        itemBuilder: (_, i) => _worldMapRow(
                          _worldMapData[i], i + 1,
                          _worldMapData[i].username == currentUsername),
                      ),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }

  String _worldMapRank(String username) {
    final i = _worldMapData.indexWhere((u) => u.username == username);
    return i != -1 ? '#${i + 1}' : 'N/A';
  }

  Widget _worldMapHeader() {
    const style = TextStyle(color: Color(0xFF0B1E3D), fontSize: 11,
        fontWeight: FontWeight.bold, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFF0B1E3D).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const SizedBox(width: 44, child: Text('Rank',      style: style, textAlign: TextAlign.center)),
        const SizedBox(width: 32),
        const Expanded(           child: Text('Explorer',  style: style)),
        const SizedBox(width: 90, child: Text('Countries', style: style, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _worldMapRow(WorldMapLeaderboardUser user, int rank, bool isMe) {
    return Container(
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF0B1E3D).withValues(alpha: 0.07) : null,
        border: isMe
            ? const Border(left: BorderSide(color: Color(0xFF0B1E3D), width: 3))
            : const Border(bottom: BorderSide(color: Color(0x11000000), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        SizedBox(width: 44, child: Center(child: _rankIcon(rank))),
        SizedBox(width: 32, child: Center(
          child: Text(_getFlagEmoji(user.countryFlag),
              style: const TextStyle(fontSize: 16)))),
        Expanded(child: _usernameCell(user.username, isMe)),
        SizedBox(width: 90, child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('${user.countriesRevealed}',
              style: const TextStyle(color: Color(0xFF0B1E3D),
                  fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 4),
            const Text('🌍', style: TextStyle(fontSize: 13)),
          ],
        )),
      ]),
    );
  }

  // ── Shared sub-widgets ─────────────────────────────────────────────────────

  Widget _loadingView() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Color(0xFF0B1E3D)),
      SizedBox(height: 16),
      Text('Loading…', style: TextStyle(color: Color(0xFF0B1E3D), fontSize: 16)),
    ]),
  );

  Widget _emptyView({String message = 'No data available'}) => Center(
    child: Text(message,
      textAlign: TextAlign.center,
      style: TextStyle(color: const Color(0xFF0B1E3D).withValues(alpha: 0.5),
          fontSize: 15, height: 1.6)),
  );

  Widget _errorBanner(String message) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.orange.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      Icon(Icons.warning, color: Colors.orange.shade800, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
        style: TextStyle(color: Colors.orange.shade900, fontSize: 12))),
    ]),
  );

  Widget _statsStrip(List<Widget> cards) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .08),
            blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: cards),
  );

  Widget _statCard(String title, String value) => Column(children: [
    Text(value,
      style: const TextStyle(color: Color(0xFF0B1E3D),
          fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text(title,
      style: TextStyle(color: const Color(0xFF0B1E3D).withValues(alpha: .7),
          fontSize: 11),
      textAlign: TextAlign.center),
  ]);

  Widget _usernameCell(String username, bool isMe) {
    final display = username.isEmpty ? ''
        : '${username[0].toUpperCase()}${username.substring(1)}';
    return Row(children: [
      Flexible(child: Text(display,
        style: TextStyle(color: const Color(0xFF0B1E3D),
            fontWeight: isMe ? FontWeight.bold : FontWeight.w500, fontSize: 14),
        overflow: TextOverflow.ellipsis)),
      if (isMe) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1E3D),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('YOU',
            style: TextStyle(color: Colors.white, fontSize: 8,
                fontWeight: FontWeight.bold)),
        ),
      ],
    ]);
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

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

class WorldMapLeaderboardUser {
  final String username;
  final String countryFlag;
  final int countriesRevealed;

  WorldMapLeaderboardUser({
    required this.username,
    required this.countryFlag,
    required this.countriesRevealed,
  });
}
