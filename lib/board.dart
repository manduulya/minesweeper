// ============================================
// File: lib/game_board.dart (MAIN FILE - REFACTORED)
// ============================================
import 'package:flutter/material.dart';
import 'package:mine_master/managers/responsive_wrapper.dart';
import 'managers/game_animation_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/game_server_service.dart';
import 'widgets/game_header_bar.dart';
import 'widgets/game_stats_widget.dart';
import 'widgets/game_action_buttons.dart';
import 'widgets/game_grid_widget.dart';
import 'package:mine_master/sound_manager.dart';
import 'game.dart';
import './dialog_utils/dialog_utils.dart';
import 'levels/levels_loader.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLevelsAndStart();
    _animationManager.startAnimations(setState, mounted);
  }

  // ============================================
  // INITIALIZATION & LEVEL LOADING
  // ============================================

  Future<void> _loadLevelsAndStart() async {
    _stateManager.levels = await loadLevels();
    print('🚀 Loading levels and starting...');

    await _loadActiveGame();

    if (_stateManager.game == null) {
      print('🚀 No active game, fetching user progress...');

      final userScore = await _serverService.getUserScore();
      final cumulativeScore = userScore?['score'] ?? 0;
      final lastCompletedLevel = userScore?['level'] ?? 0;

      print('🚀 User cumulative score: $cumulativeScore');
      print('🚀 Last completed level: $lastCompletedLevel');

      int nextLevelIndex = _determineNextLevelIndex(lastCompletedLevel);
      print('🚀 Starting at level index: $nextLevelIndex');

      _stateManager.currentLevelIndex = nextLevelIndex;
      await _initializeGameFromLevel(nextLevelIndex);

      print('🚀 Game initialized with score: ${_stateManager.game?.score}');
    } else {
      print('🚀 Active game loaded with score: ${_stateManager.game?.score}');
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

  Future<void> _initializeGameFromLevel(int levelIdx) async {
    final levelData = _stateManager.levels[levelIdx];

    final userScore = await _serverService.getUserScore();
    final currentScore = userScore?['score'] ?? 0;

    final newGame = Game(
      levelData['rows'],
      levelData['cols'],
      levelData['bombs'],
      level: levelData['level'],
      score: currentScore,
      winningStreak: _stateManager.game?.winningStreak ?? 0,
      hintCount: _stateManager.game?.hintCount ?? 3,
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

  // ============================================
  // SERVER COMMUNICATION
  // ============================================

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

      print('🔍 Fetching cumulative score for active game...');
      final userScore = await _serverService.getUserScore();
      final cumulativeScore = userScore?['score'] ?? 0;
      print('🔍 Cumulative score from database: $cumulativeScore');

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

      print('🔍 Active game loaded successfully');
    } catch (e) {
      print('❌ Error loading active game: $e');
      setState(() => _stateManager.serverConnected = false);
    }
  }

  void _reconstructGameState(
    Game game,
    Map<String, dynamic> data,
    int rows,
    int cols,
  ) {
    // Clear all bombs
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        game.board[r][c].isBomb = false;
      }
    }

    // Restore mine positions
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

    // Restore revealed cells
    if (data['revealed_cells'] != null) {
      _applyCellStates(data['revealed_cells'], rows, cols, (r, c) {
        game.board[r][c].isRevealed = true;
      });
    }

    // Restore flagged cells
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
    } catch (e) {
      print('Failed to update server game: $e');
    }
  }

  Future<void> _finishServerGame(bool won) async {
    if (!_stateManager.serverConnected ||
        _stateManager.serverGameId == null ||
        _stateManager.game == null) {
      print('⚠️ Cannot finish server game');
      return;
    }

    try {
      final hints = _stateManager.game!.hintCount;
      final streak = _stateManager.game!.winningStreak;
      final totalScore = _stateManager.game!.score;

      print('📤 Finishing game: won=$won, level=${_stateManager.game!.level}');

      final result = await _serverService.finishServerGame(
        won: won,
        level: _stateManager.game!.level,
        totalScore: totalScore,
        hints: hints,
        streak: streak,
      );

      print('✅ Server response: $result');

      if (mounted && won) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Level ${_stateManager.game!.level} completed! Score: $totalScore',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to finish server game: $e');
      _stateManager.isFinishingGame = false;
    }
  }

  // ============================================
  // GAME EVENT HANDLERS
  // ============================================

  Future<void> _handleGameWin() async {
    if (_stateManager.isFinishingGame) {
      print('⚠️ Already finishing game, skipping duplicate call');
      return;
    }

    _stateManager.isFinishingGame = true;
    _stateManager.inputLocked = true;
    _stateManager.game!.finalScore = _stateManager.game!.score;

    await _finishServerGame(true);
    _animationManager.replayAnimations(setState, mounted);

    if (mounted) {
      Future.delayed(Duration.zero, () => _showWinDialog());
    }
  }

  void handleTap(int r, int c) async {
    if (_stateManager.inputLocked) return;

    final tile = _stateManager.game!.board[r][c];

    // Hint mode handling
    if (_stateManager.isHintMode && !tile.isRevealed && !tile.isFlagged) {
      await _handleHintMode(tile);
      return;
    }

    // Normal reveal
    setState(() => _stateManager.game!.reveal(r, c));
    await _updateServerGame();

    if (_stateManager.game!.isGameOver) {
      _stateManager.inputLocked = true;
      if (_stateManager.game!.isGameWon) {
        await _handleGameWin();
      } else {
        await _finishServerGame(false);
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
      if (mounted) {
        setState(() => _stateManager.showHintDecrease = false);
      }
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
          }
        } else {
          tile.isFlagged = false;
          SoundManager.playUnflag();
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

    await _initializeGameFromLevel(_stateManager.currentLevelIndex);

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
      _initializeGameFromLevel(_stateManager.currentLevelIndex);
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

  // ============================================
  // DIALOG HANDLERS
  // ============================================

  void _handleGameStart() {
    Navigator.of(context).pop();
    setState(() => _stateManager.showStartDialog = false);
    _stateManager.game!.startTimer();
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

  // ============================================
  // UI BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    if (_stateManager.game == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: ValueKey("game-board-${_animationManager.animationKey}"),
      backgroundColor: const Color(0xFFFCF4E4),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: Column(
            children: [
              GameHeaderBar(
                level: _stateManager.game!.level,
                score: _stateManager.game!.score,
                onBackPressed: _handleBackToHome,
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GameStatsWidget(
                            remainingFlags: _stateManager.game!.remainingFlags,
                            winningStreak: _stateManager.game!.winningStreak,
                            hintCount: _stateManager.game!.hintCount,
                            showHintDecrease: _stateManager.showHintDecrease,
                            scale1: _animationManager.scale1,
                            scale2: _animationManager.scale2,
                            scale3: _animationManager.scale3,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: GameGridWidget(
                              game: _stateManager.game!,
                              onTileTap: handleTap,
                              onTileLongPress: handleFlag,
                            ),
                          ),
                          GameActionButtons(
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
