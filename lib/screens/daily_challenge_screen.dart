import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game.dart';
import '../sound_manager.dart';
import '../services/daily_challenge_service.dart';
import '../hive/offline_sync_service.dart';
import '../managers/game_animation_manager.dart';
import '../managers/responsive_wrapper.dart';
import '../widgets/game_grid_widget.dart';
import '../tile.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  late Game _game;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  final GameAnimationManager _animationManager = GameAnimationManager();

  DailyChallengeResult? _todayResult;
  bool _inputLocked = false;
  bool _isHintMode = false;
  bool _showHintDecrease = false;
  bool _isFinishing = false;
  Duration _timeUntilMidnight = Duration.zero;

  @override
  void initState() {
    super.initState();
    _todayResult = DailyChallengeService.loadTodayResult();
    _initGame();
    _animationManager.startAnimations(setState, mounted);
    _startUiTimer();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _initGame() {
    final config = DailyChallengeService.getDailyConfig();
    _game = Game(
      config.rows,
      config.cols,
      config.bombs,
      seed: config.seed,
      hintCount: 3,
    );
    if (_todayResult == null) {
      _stopwatch.start();
    } else {
      _inputLocked = true;
    }
  }

  void _startUiTimer() {
    _timeUntilMidnight = DailyChallengeService.timeUntilMidnight();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timeUntilMidnight = DailyChallengeService.timeUntilMidnight();
        });
      }
    });
  }

  // ─── Input handlers ───────────────────────────────────────────────────────

  void handleTap(int r, int c) async {
    if (_inputLocked) return;

    final tile = _game.board[r][c];

    if (_isHintMode && !tile.isRevealed && !tile.isFlagged) {
      await _handleHintMode(tile);
      return;
    }

    setState(() => _game.reveal(r, c));

    if (_game.isGameOver) {
      _inputLocked = true;
      if (_game.isGameWon) {
        await _handleWin();
      } else {
        if (_isFinishing) return;
        _isFinishing = true;
        await _showBombSequenceAndDialog();
      }
    }
  }

  void handleFlag(int r, int c) {
    if (_inputLocked) return;
    final tile = _game.board[r][c];
    setState(() {
      if (!tile.isRevealed && !_game.isGameOver) {
        if (!tile.isFlagged) {
          if (_game.remainingFlags > 0) {
            tile.isFlagged = true;
            SoundManager.playFlag();
            SoundManager.vibrateFlag();
          }
        } else {
          tile.isFlagged = false;
          SoundManager.playUnflag();
          SoundManager.vibrateUnflag();
        }
        _game.checkWin();
      }
    });

    if (_game.isGameWon && _game.isGameOver) {
      _handleWin();
    }
  }

  Future<void> _handleHintMode(Tile tile) async {
    setState(() => tile.isHintAnimating = true);

    final frames = ["flag", "question", "exclamation", "safe"];
    for (final frame in frames) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => tile.hintFrame = frame);
    }

    setState(() {
      tile.isHintAnimating = false;
      tile.hintFrame = null;
      if (tile.isBomb) {
        tile.isFlagged = true;
        tile.isSafelyRevealed = true;
      } else {
        tile.isRevealed = true;
        tile.isHintRevealed = true;
      }
      _game.hintCount--;
      _showHintDecrease = true;
      _isHintMode = false;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showHintDecrease = false);
    });

    _game.checkWin();
    if (_game.isGameWon && _game.isGameOver) {
      await _handleWin();
    }
  }

  // ─── Win / loss ────────────────────────────────────────────────────────────

  Future<void> _handleWin() async {
    if (_isFinishing) return;
    _isFinishing = true;
    _stopwatch.stop();
    _inputLocked = true;

    final hintsUsed = 3 - _game.hintCount;
    final result = DailyChallengeResult(
      won: true,
      timeSeconds: _stopwatch.elapsed.inSeconds,
      hintsUsed: hintsUsed,
      cleanWin: hintsUsed == 0,
    );

    // Grant +1 hint reward if under the 10-hint cap.
    final cachedStats = OfflineSyncService.getCachedStats();
    final currentHints = cachedStats?['hints'] as int? ?? _game.hintCount;
    final hintRewarded = currentHints < 10;
    if (hintRewarded && cachedStats != null) {
      cachedStats['hints'] = currentHints + 1;
      OfflineSyncService.cacheStats(cachedStats);
    }

    await DailyChallengeService.saveResult(result);
    setState(() => _todayResult = result);

    _animationManager.replayAnimations(setState, mounted);

    if (mounted) {
      Future.delayed(Duration.zero, () => _showWinDialog(result, hintRewarded: hintRewarded));
    }
  }

  Future<void> _showBombSequenceAndDialog() async {
    final bombPositions = _game.getUnrevealedBombPositions()..shuffle();
    if (bombPositions.isEmpty) {
      _showLossDialog();
      return;
    }

    final delayMs =
        bombPositions.length > 1 ? (1000 / bombPositions.length).round() : 1000;

    for (int i = 0; i < bombPositions.length; i++) {
      setState(() => _game.revealBombAt(bombPositions[i][0], bombPositions[i][1]));
      if (i < bombPositions.length - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    setState(() => _game.stopBombAnimations());
    _showLossDialog();
  }

  void _restartGame() {
    _stopwatch.reset();
    _stopwatch.start();
    _isFinishing = false;
    final config = DailyChallengeService.getDailyConfig();
    setState(() {
      _game = Game(
        config.rows,
        config.cols,
        config.bombs,
        seed: config.seed,
        hintCount: 3,
      );
      _inputLocked = false;
      _isHintMode = false;
    });
    _animationManager.replayAnimations(setState, mounted);
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  void _showWinDialog(DailyChallengeResult result, {bool hintRewarded = true}) {
    final streak = DailyChallengeService.getDailyStreak();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WinDialog(
        result: result,
        streak: streak,
        hintRewarded: hintRewarded,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showLossDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0B1E3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Better luck tomorrow!',
          style: TextStyle(color: Colors.white, fontFamily: 'Acsioma'),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'The board is the same — try again!',
          style: TextStyle(color: Color(0xFFC0C0C0)),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // back to home
            },
            child: const Text('Give Up', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final challengeNum = DailyChallengeService.getChallengeNumber();
    final elapsedSec = _stopwatch.elapsed.inSeconds;

    // If already completed today, show result overlay on top of the locked board
    final alreadyWon = _todayResult?.won == true;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/background1.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),

          SafeArea(
            child: ResponsiveWrapper(
              child: Column(
                children: [
                  // Header
                  _buildHeader(challengeNum, elapsedSec, alreadyWon),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Stats row
                          _buildStatsRow(),
                          const SizedBox(height: 12),

                          // Board
                          _buildWoodFrame(
                            child: GameGridWidget(
                              game: _game,
                              onTileTap: handleTap,
                              onTileLongPress: handleFlag,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Action buttons (hidden when already won)
                          if (!alreadyWon)
                            _buildActionButtons(isCompact),

                          // Countdown when already won
                          if (alreadyWon) ...[
                            const SizedBox(height: 8),
                            _buildCountdown(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int challengeNum, int elapsedSec, bool alreadyWon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Daily Challenge #$challengeNum',
                  style: const TextStyle(
                    color: Color(0xFFFFDD00),
                    fontFamily: 'Acsioma',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
                if (!alreadyWon)
                  Text(
                    DailyChallengeService.formatTime(elapsedSec),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          // Share button (only when completed)
          if (alreadyWon && _todayResult != null)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white70),
              tooltip: 'Copy result',
              onPressed: () => _copyResult(_todayResult!),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statChip(Icons.flag, '${_game.remainingFlags}', Colors.redAccent),
        const SizedBox(width: 16),
        _statChip(Icons.lightbulb_outline, '${_game.hintCount}', const Color(0xFFFFDD00),
            dimming: _showHintDecrease),
        const SizedBox(width: 16),
        _statChip(Icons.local_fire_department,
            '${DailyChallengeService.getDailyStreak()}', Colors.orangeAccent),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, Color color, {bool dimming = false}) {
    return AnimatedOpacity(
      opacity: dimming ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Hint toggle
        _actionButton(
          icon: _isHintMode ? Icons.lightbulb : Icons.lightbulb_outline,
          label: 'Hint',
          color: _isHintMode
              ? const Color(0xFFFFDD00)
              : (_game.hintCount > 0 ? Colors.white : Colors.grey),
          onPressed: _game.hintCount > 0 && !_game.isGameOver
              ? () => setState(() => _isHintMode = !_isHintMode)
              : null,
        ),
        const SizedBox(width: 24),
        // Restart
        _actionButton(
          icon: Icons.refresh,
          label: 'Restart',
          color: Colors.white70,
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF0B1E3D),
                title: const Text('Restart?',
                    style: TextStyle(color: Colors.white)),
                content: const Text('Reset the board and try again.',
                    style: TextStyle(color: Color(0xFFC0C0C0))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child:
                        const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _restartGame();
                    },
                    child: const Text('Restart'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed != null ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28,
                shadows: const [Shadow(color: Colors.black, blurRadius: 8)]),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        const Text(
          'Next challenge in',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          DailyChallengeService.formatCountdown(_timeUntilMidnight),
          style: const TextStyle(
            color: Color(0xFFFFDD00),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ],
    );
  }

  Widget _buildWoodFrame({required Widget child}) {
    const frameRadius = 16.0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(frameRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A3316), Color(0xFF7A4A22), Color(0xFF4A2A12)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFF2F190A), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frameRadius - 6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFCF4E4), Color(0xFFF3E4C8), Color(0xFFE6D1A8)],
            ),
            borderRadius: BorderRadius.circular(frameRadius - 6),
          ),
          child: child,
        ),
      ),
    );
  }

  void _copyResult(DailyChallengeResult result) {
    Clipboard.setData(ClipboardData(
      text: DailyChallengeService.buildShareText(result),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─── Win dialog ──────────────────────────────────────────────────────────────

class _WinDialog extends StatelessWidget {
  final DailyChallengeResult result;
  final int streak;
  final bool hintRewarded;
  final VoidCallback onDone;

  const _WinDialog({
    required this.result,
    required this.streak,
    required this.hintRewarded,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DailyChallengeService.formatTime(result.timeSeconds);
    final challengeNum = DailyChallengeService.getChallengeNumber();

    return AlertDialog(
      backgroundColor: const Color(0xFF0B1E3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        hintRewarded ? 'Challenge Complete!' : 'Awesome job!',
        style: const TextStyle(
          color: Color(0xFFFFDD00),
          fontFamily: 'Acsioma',
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$challengeNum',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _row(Icons.timer, 'Time', timeStr),
          const SizedBox(height: 6),
          _row(Icons.lightbulb_outline, 'Hints used', '${result.hintsUsed}'),
          if (result.cleanWin) ...[
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Color(0xFFFFDD00), size: 16),
                SizedBox(width: 4),
                Text('Clean win — no hints!',
                    style: TextStyle(
                        color: Color(0xFFFFDD00),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          // Hint reward row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb,
                  color: hintRewarded ? const Color(0xFFFFDD00) : Colors.white38,
                  size: 16),
              const SizedBox(width: 4),
              Text(
                hintRewarded ? '+1 hint rewarded' : 'Hints full (10/10)',
                style: TextStyle(
                  color: hintRewarded ? const Color(0xFFFFDD00) : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$streak day streak',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
          label: const Text('Copy', style: TextStyle(color: Colors.white54)),
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: DailyChallengeService.buildShareText(result),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Result copied!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        ElevatedButton(
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.white54)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
