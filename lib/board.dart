import 'package:flutter/material.dart';
import 'package:mine_master/managers/responsive_wrapper.dart';
import 'managers/game_animation_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/game_server_service.dart';
import 'services/interstitial_ad_service.dart';
import 'widgets/game_header_bar.dart';
import 'widgets/game_stats_widget.dart';
import 'widgets/game_action_buttons.dart';
import 'widgets/game_grid_widget.dart';
import 'package:mine_master/sound_manager.dart';
import 'game.dart';
import './dialog_utils/dialog_utils.dart';
import 'levels/levels_loader.dart';
import 'hive/offline_sync_service.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  // Managers
  final GameAnimationManager _animationManager = GameAnimationManager();
  final GameStateManager _stateManager = GameStateManager();
  final GameServerService _serverService = GameServerService();
  final InterstitialAdService _interstitialAdService = InterstitialAdService();

  // Score captured at the exact moment of a win — before any async work that
  // could theoretically disturb game.score. Used by _startNextLevel so the
  // carry-over score is always the value the player actually earned.
  int? _scoreAtWin;

  @override
  void initState() {
    super.initState();
    _loadLevelsAndStart();
    _animationManager.startAnimations(setState, mounted);
    _interstitialAdService.preloadAd();
  }

  // ============================================
  // INITIALIZATION & LEVEL LOADING
  // ============================================

  Future<void> _loadLevelsAndStart() async {
    // Force a fresh score fetch for this session — the static TTL cache may
    // hold a stale value from the previous board open (e.g. pre-win score).
    _serverService.invalidateScoreCache();
    _stateManager.levels = await loadLevels();

    await _loadActiveGame();

    if (_stateManager.game == null) {
      // Fetch score and stats in parallel so we have fresh hints/streak from DB.
      final results = await Future.wait([
        _serverService.getUserScore(),
        _serverService.getUserStats(),
      ]);
      final userScore = results[0];
      final userStats = results[1];
      final currentScore = userScore?['score'] as int? ?? 0;
      final lastCompletedLevel = userScore?['level'] as int? ?? 0;
      final freshHints = userStats?['hints'] as int? ?? 3;
      final freshStreak = userStats?['streak'] as int? ?? 0;

      int nextLevelIndex = _determineNextLevelIndex(lastCompletedLevel);

      _stateManager.currentLevelIndex = nextLevelIndex;
      await _initializeGameFromLevel(
        nextLevelIndex,
        scoreOverride: currentScore,
        hintsOverride: freshHints,
        streakOverride: freshStreak,
      );
    }
  }

  int _determineNextLevelIndex(int lastCompletedLevel) {
    if (lastCompletedLevel == 0) return 0;

    int nextLevelIndex = _stateManager.levels.indexWhere(
      (level) => level['level'] == lastCompletedLevel + 1,
    );

    if (nextLevelIndex == -1) {
      nextLevelIndex = _stateManager.levels.indexWhere(
        (level) => level['level'] == lastCompletedLevel,
      );
    }

    return nextLevelIndex == -1 ? 0 : nextLevelIndex;
  }

  Future<void> _initializeGameFromLevel(
    int levelIdx, {
    int? scoreOverride,
    int? hintsOverride,
    int? streakOverride,
  }) async {
    final levelData = _stateManager.levels[levelIdx];

    // Use scoreOverride when the score is already known (level transitions,
    // restarts) to avoid an async network gap that leaves the header stale.
    // Only fetch from the server on a fresh board open (scoreOverride == null).
    final int currentScore;
    if (scoreOverride != null) {
      currentScore = scoreOverride;
    } else {
      final userScore = await _serverService.getUserScore();
      currentScore = userScore?['score'] ?? 0;
    }

    // Priority: explicit overrides (fresh from DB) > live game values > cache.
    final cachedStats = (_stateManager.game == null && hintsOverride == null)
        ? OfflineSyncService.getCachedStats()
        : null;
    final int resolvedStreak = _stateManager.game?.winningStreak ??
        streakOverride ??
        (cachedStats?['streak'] as int? ?? 0);
    final int resolvedHints = _stateManager.game?.hintCount ??
        hintsOverride ??
        (cachedStats?['hints'] as int? ?? 3);

    final newGame = Game(
      levelData['rows'],
      levelData['cols'],
      levelData['bombs'],
      level: levelData['level'],
      score: currentScore,
      winningStreak: resolvedStreak,
      hintCount: resolvedHints,
      shape: (levelData['shape'] as List)
          .map((row) => (row as List).map((e) => e as int).toList())
          .toList(),
    );

    setState(() {
      _stateManager.game = newGame;
      _stateManager.showStartDialog = true;
      _stateManager.serverGameId = null;
      _stateManager.serverConnected = false;
    });

    _animationManager.replayAnimations(setState, mounted);
    await _startServerGame();
  }

  Future<void> _startServerGame() async {
    if (_stateManager.game == null) return;

    try {
      final result = await _serverService.startServerGame(
        cols: _stateManager.game!.cols,
        rows: _stateManager.game!.rows,
        bombCount: _stateManager.game!.bombCount,
        minePositions: _stateManager.getMinePositions(),
        level: _stateManager.game!.level,
        hintCount: _stateManager.game!.hintCount,
        winningStreak: _stateManager.game!.winningStreak,
      );

      final rawGameId = result['game_id'];
      final parsedGameId = rawGameId is int
          ? rawGameId
          : int.tryParse(rawGameId.toString());

      setState(() {
        _stateManager.serverGameId = parsedGameId;
        _stateManager.serverConnected = true;
      });
    } catch (e) {
      setState(() {
        _stateManager.serverConnected = false;
      });
    }
  }

  Future<void> _loadActiveGame() async {
    try {
      final gameData = await _serverService.loadCurrentGame();
      if (gameData == null ||
          gameData['level'] == null ||
          gameData['game_id'] == null) {
        return;
      }

      final levelNumber = gameData['level'] as int;
      final gameId = gameData['game_id'] as int;

      final levelIndex = _stateManager.levels.indexWhere(
        (level) => level['level'] == levelNumber,
      );

      if (levelIndex == -1) return;

      final levelData = _stateManager.levels[levelIndex];
      final rows = levelData['rows'] as int;
      final cols = levelData['cols'] as int;
      final bombs = levelData['bombs'] as int;

      final serverHints = gameData['hints'] as int? ?? 3;
      final serverStreak = gameData['streak'] as int? ?? 0;

      final userScore = await _serverService.getUserScore();
      final cumulativeScore = userScore?['score'] ?? 0;

      final newGame = Game(
        rows,
        cols,
        bombs,
        level: levelNumber,
        score: cumulativeScore,
        winningStreak: serverStreak,
        hintCount: serverHints,
        shape: (levelData['shape'] as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList(),
      );

      _reconstructGameState(newGame, gameData, rows, cols);

      final gameStatus = gameData['game_status'] as String? ?? 'active';
      _applyGameStatus(newGame, gameStatus);

      setState(() {
        _stateManager.game = newGame;
        _stateManager.serverGameId = gameId;
        _stateManager.gameStartTime = DateTime.now();
        _stateManager.serverConnected = true;
        _stateManager.currentLevelIndex = levelIndex;
      });

      if (newGame.isGameOver && !newGame.isGameWon) {
        _showGameOverDialog();
      }
    } catch (e) {
      setState(() => _stateManager.serverConnected = false);
    }
  }

  void _reconstructGameState(
    Game game,
    Map<String, dynamic> data,
    int rows,
    int cols,
  ) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        game.board[r][c].isBomb = false;
      }
    }

    if (data['mine_positions'] != null) {
      final minePositions = data['mine_positions'] as List;
      for (var pos in minePositions) {
        if (pos is List && pos.length >= 2) {
          final row = pos[0] as int;
          final col = pos[1] as int;
          if (row >= 0 && row < rows && col >= 0 && col < cols) {
            game.board[row][col].isBomb = true;
          }
        }
      }
    }

    game.calculateAdjacency();

    if (data['revealed_cells'] != null) {
      _applyCellStates(data['revealed_cells'], rows, cols, (r, c) {
        game.board[r][c].isRevealed = true;
      });
    }

    if (data['flagged_cells'] != null) {
      _applyCellStates(data['flagged_cells'], rows, cols, (r, c) {
        game.board[r][c].isFlagged = true;
      });
    }
  }

  void _applyCellStates(
    List cells,
    int rows,
    int cols,
    Function(int, int) action,
  ) {
    for (var cell in cells) {
      if (cell is List && cell.length >= 2) {
        final row = cell[0] as int;
        final col = cell[1] as int;
        if (row >= 0 && row < rows && col >= 0 && col < cols) {
          action(row, col);
        }
      }
    }
  }

  void _applyGameStatus(Game game, String status) {
    if (status == 'lost') {
      game.isGameOver = true;
      game.isGameWon = false;
      _stateManager.inputLocked = true;
    } else if (status == 'won') {
      game.isGameOver = true;
      game.isGameWon = true;
      _stateManager.inputLocked = true;
    } else {
      game.isGameOver = false;
      game.isGameWon = false;
      _stateManager.inputLocked = false;
    }
  }

  Future<void> _updateServerGame() async {
    if (!_stateManager.serverConnected || _stateManager.serverGameId == null) {
      return;
    }

    try {
      await _serverService.updateServerGame(
        gameId: _stateManager.serverGameId!,
        revealedCells: _stateManager.getRevealedCells(),
        flaggedCells: _stateManager.getFlaggedCells(),
        hintCount: _stateManager.game!.hintCount,
      );
    } catch (_) {}
  }

  Future<void> _finishServerGame(bool won) async {
    if (_stateManager.game == null) return;

    // Always call the service — it handles both online (syncs to server) and
    // offline (queues result + clears Hive game cache) cases internally.
    // The old serverConnected guard was preventing clearGameState() from
    // running offline, which left a stale completed game in the cache and
    // caused the board to reload in a locked state on the next session.
    try {
      await _serverService.finishServerGame(
        won: won,
        level: _stateManager.game!.level,
        totalScore: _stateManager.game!.score,
        hints: _stateManager.game!.hintCount,
        streak: _stateManager.game!.winningStreak,
      );
    } catch (_) {
      _stateManager.isFinishingGame = false;
    }
  }

  Future<void> _handleGameWin() async {
    if (_stateManager.isFinishingGame) return;

    _stateManager.isFinishingGame = true;
    _stateManager.inputLocked = true;
    _stateManager.game!.finalScore = _stateManager.game!.score;
    // Capture the winning score synchronously before any async work so that
    // _startNextLevel always carries the correct value even if game state is
    // disturbed while finishServerGame is awaited.
    _scoreAtWin = _stateManager.game!.score;

    await _finishServerGame(true);
    _animationManager.replayAnimations(setState, mounted);
    await _interstitialAdService.onRoundComplete();

    if (mounted) {
      Future.delayed(Duration.zero, () => _showWinDialog());
    }
  }

  void handleTap(int r, int c) async {
    if (_stateManager.inputLocked) return;

    final tile = _stateManager.game!.board[r][c];

    if (_stateManager.isHintMode && !tile.isRevealed && !tile.isFlagged) {
      await _handleHintMode(tile);
      return;
    }

    setState(() => _stateManager.game!.reveal(r, c));
    await _updateServerGame();

    if (_stateManager.game!.isGameOver) {
      _stateManager.inputLocked = true;
      if (_stateManager.game!.isGameWon) {
        await _handleGameWin();
      } else {
        await _finishServerGame(false);
        await _interstitialAdService.onRoundComplete();
        await _showBombSequenceAndDialog();
      }
    }
  }

  Future<void> _handleHintMode(dynamic tile) async {
    setState(() => tile.isHintAnimating = true);

    final frames = ["flag", "question", "exclamation", "safe"];
    for (int i = 0; i < frames.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => tile.hintFrame = frames[i]);
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

      _stateManager.game!.hintCount--;
      _stateManager.showHintDecrease = true;
      _stateManager.isHintMode = false;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _stateManager.showHintDecrease = false);
    });

    await _updateServerGame();
    _stateManager.game!.checkWin();

    if (_stateManager.game!.isGameWon && _stateManager.game!.isGameOver) {
      await _handleGameWin();
    }
  }

  void handleFlag(int r, int c) async {
    if (_stateManager.inputLocked) return;

    final tile = _stateManager.game!.board[r][c];

    setState(() {
      if (!tile.isRevealed && !_stateManager.game!.isGameOver) {
        if (!tile.isFlagged) {
          if (_stateManager.game!.remainingFlags > 0) {
            tile.isFlagged = true;
            SoundManager.playFlag();
            SoundManager.vibrateFlag();
          }
        } else {
          tile.isFlagged = false;
          SoundManager.playUnflag();
          SoundManager.vibrateUnflag();
        }
        _stateManager.game!.checkWin();
      }
    });

    await _updateServerGame();

    if (_stateManager.game!.isGameWon && _stateManager.game!.isGameOver) {
      await _handleGameWin();
    }
  }

  Future<void> _showBombSequenceAndDialog() async {
    _stateManager.inputLocked = true;
    List<List<int>> bombPositions = _stateManager.game!
        .getUnrevealedBombPositions();
    bombPositions.shuffle();

    if (bombPositions.isEmpty) {
      _showGameOverDialog();
      return;
    }

    int totalBombs = bombPositions.length;
    int delayMs = totalBombs > 1 ? (1000 / totalBombs).round() : 1000;

    for (int i = 0; i < bombPositions.length; i++) {
      int r = bombPositions[i][0];
      int c = bombPositions[i][1];

      setState(() => _stateManager.game!.revealBombAt(r, c));

      if (i < bombPositions.length - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    setState(() => _stateManager.game!.stopBombAnimations());

    _showGameOverDialog();
  }

  Future<void> _restartGame() async {
    bool isLoss =
        _stateManager.game!.isGameOver && !_stateManager.game!.isGameWon;
    _stateManager.isFinishingGame = false;

    await _initializeGameFromLevel(
      _stateManager.currentLevelIndex,
      scoreOverride: _stateManager.game!.score,
    );

    setState(() {
      _stateManager.inputLocked = false;
      if (isLoss) _stateManager.game!.winningStreak = 0;
    });

    _animationManager.replayAnimations(setState, mounted);
  }

  void _startNextLevel() {
    _stateManager.isFinishingGame = false;
    setState(() => _stateManager.inputLocked = false);

    if (_stateManager.currentLevelIndex + 1 < _stateManager.levels.length) {
      _stateManager.currentLevelIndex++;
      _initializeGameFromLevel(
        _stateManager.currentLevelIndex,
        scoreOverride: _scoreAtWin ?? _stateManager.game!.score,
      );
      _scoreAtWin = null;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Congratulations! You finished all levels!'),
        ),
      );
      _stateManager.showStartDialog = true;
      _stateManager.game!.finalScore = _stateManager.game!.score;
    }
  }


  void _showGameOverDialog() {
    _animationManager.replayAnimations(setState, mounted);
    DialogUtils.showGameOverDialog(
      context: context,
      game: _stateManager.game!,
      onRetry: _restartGame,
    );
  }

  void _showWinDialog() {
    DialogUtils.showWinDialog(
      context: context,
      game: _stateManager.game!,
      onNextLevel: _startNextLevel,
    );
  }

  Future<void> _handleBackToHome() async {
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildWoodFrame({required Widget child}) {
    const frameRadius = 16.0;

    return Container(
      padding: const EdgeInsets.all(8), // ✅ thinner frame (was 14)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(frameRadius),

        // dark wood border
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
        border: Border.all(
          color: const Color(0xFF2F190A),
          width: 1.5, // ✅ thinner border
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frameRadius - 6),
        child: Container(
          padding: const EdgeInsets.all(6), // ✅ thinner inner padding (was 12)
          decoration: BoxDecoration(
            // bright parchment background
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 400;

    if (_stateManager.game == null) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/background1.webp',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            Container(color: Colors.black.withValues(alpha: 0.25)),
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFDD00)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: ValueKey("game-board-${_animationManager.animationKey}"),
      body: Stack(
        fit: StackFit.expand,
        children: [
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
                  GameHeaderBar(
                    level: _stateManager.game!.level,
                    score: _stateManager.game!.score,
                    onBackPressed: _handleBackToHome,
                    // ✅ You'll update the widget to use this style,
                    // but leaving these values here is harmless even if ignored.
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GameStatsWidget(
                                remainingFlags:
                                    _stateManager.game!.remainingFlags,
                                winningStreak:
                                    _stateManager.game!.winningStreak,
                                hintCount: _stateManager.game!.hintCount,
                                showHintDecrease:
                                    _stateManager.showHintDecrease,
                                scale1: _animationManager.scale1,
                                scale2: _animationManager.scale2,
                                scale3: _animationManager.scale3,
                              ),
                              const SizedBox(height: 12),

                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.58,
                                child: Center(
                                  child: _buildWoodFrame(
                                    child: GameGridWidget(
                                      game: _stateManager.game!,
                                      onTileTap: handleTap,
                                      onTileLongPress: handleFlag,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),
                              GameActionButtons(
                                compact: isCompact,
                                isHintMode: _stateManager.isHintMode,
                                canUseHint:
                                    _stateManager.game!.hintCount > 0 &&
                                    !_stateManager.game!.isGameOver,
                                onHintPressed: () {
                                  setState(() {
                                    _stateManager.isHintMode =
                                        !_stateManager.isHintMode;
                                  });
                                },
                                onRestartPressed: _restartGame,
                                hintOffset: _animationManager.hintOffset,
                                restartOffset: _animationManager.restartOffset,
                                bottomPadding: 50,
                              ),
                            ],
                          ),
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
}
