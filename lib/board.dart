import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import 'package:mobile_experiment/sound_manager.dart';
import 'game.dart';
import 'tile_widget.dart';
import './dialog_utils/dialog_utils.dart';
import 'levels/levels_loader.dart';
import 'services/api_service.dart';
import 'service_utils/error_handler.dart';
import 'service_utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  Game? game;
  bool _showStartDialog = false;
  bool isHintMode = false;
  bool _inputLocked = false;
  bool _isFinishingGame = false;
  bool _showHintDecrease = false;

  List<Map<String, dynamic>> levels = [];
  int currentLevelIndex = 0;

  // Server integration variables
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();
  int? serverGameId;
  DateTime? gameStartTime;
  bool serverConnected = false;

  List<List<int>> _getRevealedCells() {
    final revealed = <List<int>>[];
    for (int r = 0; r < game!.board.length; r++) {
      for (int c = 0; c < game!.board[r].length; c++) {
        if (game!.board[r][c].isRevealed) {
          revealed.add([r, c]);
        }
      }
    }
    return revealed;
  }

  List<List<int>> _getFlaggedCells() {
    final flagged = <List<int>>[];
    for (int r = 0; r < game!.board.length; r++) {
      for (int c = 0; c < game!.board[r].length; c++) {
        if (game!.board[r][c].isFlagged) {
          flagged.add([r, c]);
        }
      }
    }
    return flagged;
  }

  @override
  void initState() {
    super.initState();
    _loadLevelsAndStart();
  }

  Future<void> _loadLevelsAndStart() async {
    levels = await loadLevels();

    print('🚀 Loading levels and starting...');

    // Try to load an active game from server first
    await _loadActiveGame();

    // If no active game was loaded, start a new one with user's cumulative score
    if (game == null) {
      print('🚀 No active game, fetching user progress...');

      // Fetch user's progress from database
      final userScore = await _apiService.getUserScore();
      final cumulativeScore = userScore?['score'] ?? 0;
      final lastCompletedLevel = userScore?['level'] ?? 0;

      print('🚀 User cumulative score: $cumulativeScore');
      print('🚀 Last completed level: $lastCompletedLevel');

      // Determine which level to start
      int nextLevelIndex = 0;
      if (lastCompletedLevel > 0) {
        // Find index of next level after last completed
        nextLevelIndex = levels.indexWhere(
          (level) => level['level'] == lastCompletedLevel + 1,
        );

        // If not found, start from last completed level
        if (nextLevelIndex == -1) {
          nextLevelIndex = levels.indexWhere(
            (level) => level['level'] == lastCompletedLevel,
          );
        }

        // If still not found, start from beginning
        if (nextLevelIndex == -1) {
          nextLevelIndex = 0;
        }
      }

      print('🚀 Starting at level index: $nextLevelIndex');

      currentLevelIndex = nextLevelIndex;
      await _initializeGameFromLevel(currentLevelIndex);

      print('🚀 Game initialized with score: ${game?.score}');
    } else {
      print('🚀 Active game loaded with score: ${game?.score}');
    }
  }

  Future<void> _initializeGameFromLevel(int levelIdx) async {
    final levelData = levels[levelIdx];

    // Fetch current score from database
    final userScore = await _apiService.getUserScore();
    final currentScore = userScore?['score'] ?? 0;

    final newGame = Game(
      levelData['rows'],
      levelData['cols'],
      levelData['bombs'],
      level: levelData['level'],
      score: currentScore, // ← Use score from database
      winningStreak: game?.winningStreak ?? 0,
      hintCount: game?.hintCount ?? 3,
      shape: (levelData['shape'] as List)
          .map((row) => (row as List).map((e) => e as int).toList())
          .toList(),
    );

    setState(() {
      game = newGame;
      _showStartDialog = true;
      serverGameId = null;
      serverConnected = false;
    });

    // Start server game
    await _startServerGame();
  }

  Future<void> _startServerGame() async {
    if (game == null) return;

    try {
      // Convert your mine positions to server format
      List<List<int>> minePositions = _getMinePositions();

      final result = await _apiService.startGame(
        game!.cols, // cols
        game!.rows, // rows
        game!.bombCount, // bombCount
        minePositions, // minePositions
        game!.level, // levelId
        game!.hintCount,
        game!.winningStreak,
      );

      // Handle both int or string responses just in case
      final rawGameId = result['game_id'];
      final parsedGameId = rawGameId is int
          ? rawGameId
          : int.tryParse(rawGameId.toString());

      setState(() {
        serverGameId = parsedGameId;
        serverConnected = true;
      });
    } catch (e) {
      setState(() {
        serverConnected = false;
      });
    }
  }

  // Convert your game's mine positions to server format
  List<List<int>> _getMinePositions() {
    List<List<int>> minePositions = [];
    for (int r = 0; r < game!.rows; r++) {
      for (int c = 0; c < game!.cols; c++) {
        if (game!.board[r][c].isBomb) {
          minePositions.add([r, c]);
        }
      }
    }
    return minePositions;
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch revealed cells from server
  Future<List<List<int>>> getRevealedCells(int gameId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/game/$gameId/revealed'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<List<int>>.from(
        (data['revealed_cells'] as List).map((row) => List<int>.from(row)),
      );
    } else {
      throw Exception(
        'Failed to fetch revealed cells: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Fetch flagged cells from server
  Future<List<List<int>>> getFlaggedCells(int gameId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/game/$gameId/flagged'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<List<int>>.from(
        (data['flagged_cells'] as List).map((row) => List<int>.from(row)),
      );
    } else {
      throw Exception(
        'Failed to fetch flagged cells: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> _loadActiveGame() async {
    try {
      final gameData = await _apiService.loadCurrentGame();

      if (gameData == null) {
        return;
      }

      // Check for nulls before casting
      if (gameData['level'] == null) {
        return;
      }

      if (gameData['game_id'] == null) {
        return;
      }

      // Safe extraction with explicit null checks
      final levelNumber = gameData['level'] as int;
      final gameId = gameData['game_id'] as int;

      // Find the matching level data
      final levelIndex = levels.indexWhere(
        (level) => level['level'] == levelNumber,
      );

      if (levelIndex == -1) {
        return;
      }

      final levelData = levels[levelIndex];

      // Extract grid dimensions from level data
      final rows = levelData['rows'] as int;
      final cols = levelData['cols'] as int;
      final bombs = levelData['bombs'] as int;

      final serverHints = gameData['hints'] as int? ?? 3;
      final serverStreak = gameData['streak'] as int? ?? 0;

      // ✅ FETCH CUMULATIVE SCORE FROM DATABASE
      print('🔍 Fetching cumulative score for active game...');
      final userScore = await _apiService.getUserScore();
      final cumulativeScore = userScore?['score'] ?? 0;
      print('🔍 Cumulative score from database: $cumulativeScore');

      // Create a new game with the level configuration
      final newGame = Game(
        rows,
        cols,
        bombs,
        level: levelNumber,
        score: cumulativeScore, // ✅ Use cumulative score from database
        winningStreak: serverStreak,
        hintCount: serverHints,
        shape: (levelData['shape'] as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList(),
      );

      print('🔍 Active game created with score: ${newGame.score}');

      // CLEAR all bombs that were randomly generated
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          newGame.board[r][c].isBomb = false;
        }
      }

      // Reconstruct mine positions
      if (gameData['mine_positions'] != null) {
        final minePositions = gameData['mine_positions'] as List;
        for (var pos in minePositions) {
          if (pos is List && pos.length >= 2) {
            final row = pos[0] as int;
            final col = pos[1] as int;
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
              newGame.board[row][col].isBomb = true;
            }
          }
        }
      }

      newGame.calculateAdjacency();

      // Apply revealed cells
      if (gameData['revealed_cells'] != null) {
        final revealedCells = gameData['revealed_cells'] as List;
        for (var cell in revealedCells) {
          if (cell is List && cell.length >= 2) {
            final row = cell[0] as int;
            final col = cell[1] as int;
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
              newGame.board[row][col].isRevealed = true;
            }
          }
        }
      }

      // Apply flagged cells
      if (gameData['flagged_cells'] != null) {
        final flaggedCells = gameData['flagged_cells'] as List;
        for (var cell in flaggedCells) {
          if (cell is List && cell.length >= 2) {
            final row = cell[0] as int;
            final col = cell[1] as int;
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
              newGame.board[row][col].isFlagged = true;
            }
          }
        }
      }
      final gameStatus = gameData['game_status'] as String? ?? 'active';
      if (gameStatus == 'lost') {
        newGame.isGameOver = true;
        newGame.isGameWon = false;
        _inputLocked = true; // prevent further interaction until restart
      } else if (gameStatus == 'won') {
        newGame.isGameOver = true;
        newGame.isGameWon = true;
        _inputLocked = true;
      } else {
        newGame.isGameOver = false;
        newGame.isGameWon = false;
        _inputLocked = false;
      }

      setState(() {
        game = newGame;
        serverGameId = gameId;
        gameStartTime = DateTime.now();
        serverConnected = true;
        currentLevelIndex = levelIndex;
      });

      if (newGame.isGameOver && !newGame.isGameWon) {
        _showGameOverDialog();
      }

      print('🔍 Active game loaded successfully with score: ${game?.score}');
    } catch (e) {
      print('❌ Error loading active game: $e');
      setState(() {
        serverConnected = false;
      });
    }
  }

  Future<void> _updateServerGame() async {
    if (!serverConnected || serverGameId == null) return;

    try {
      await _apiService.updateGame(
        serverGameId!,
        _getRevealedCells(),
        _getFlaggedCells(),
        hintCount: game!.hintCount, // <- send hint count
      );
    } catch (e) {
      print('Failed to update server game: $e');
    }
  }

  Future<void> _handleGameWin() async {
    if (_isFinishingGame) {
      print('⚠️ Already finishing game, skipping duplicate call');
      return;
    }

    _isFinishingGame = true; // ← Set the flag!
    _inputLocked = true;
    game!.finalScore = game!.score;

    await _finishServerGame(true);

    if (mounted) {
      Future.delayed(Duration.zero, () {
        _showWinDialog();
      });
    }
  }

  Future<void> _finishServerGame(bool won) async {
    if (!serverConnected || serverGameId == null || game == null) {
      print(
        '⚠️ Cannot finish server game: serverConnected=$serverConnected, serverGameId=$serverGameId, game=${game != null}',
      );
      return;
    }

    try {
      final hints = game!.hintCount;
      final streak = game!.winningStreak;
      final totalScore = game!.score;

      print('📤 Finishing game on server:');
      print('   - won: $won');
      print('   - level: ${game!.level}');
      print('   - score: $totalScore');
      print('   - hints: $hints');
      print('   - streak: $streak');

      final result = await _apiService.finishGame(
        won,
        game!.level,
        totalScore,
        hints,
        streak,
      );

      print('✅ Server response: $result');

      if (mounted && won) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Level ${game!.level} completed! Total Score: $totalScore',
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to finish server game: $e');
      _isFinishingGame = false; // ← Reset on error
    }
    // Don't reset flag on success - prevent any future calls for this game
  }

  void _handleGameStart() {
    Navigator.of(context).pop();
    setState(() {
      _showStartDialog = false;
    });
    game!.startTimer();
  }

  void _showGameStartDialog() {
    DialogUtils.showGameStartDialog(
      context: context,
      game: game!,
      onStart: _handleGameStart,
    );
  }

  void handleTap(int r, int c) async {
    if (_inputLocked) return;

    final tile = game!.board[r][c];

    // === Hint mode ===
    if (isHintMode && !tile.isRevealed && !tile.isFlagged) {
      setState(() {
        tile.isHintAnimating = true;
      });

      // Animation frames
      final frames = ["flag", "question", "exclamation", "safe"];

      for (int i = 0; i < frames.length; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        setState(() {
          tile.hintFrame = frames[i];
        });
      }

      // End animation
      setState(() {
        tile.isHintAnimating = false;
        tile.hintFrame = null;
      });

      // Now apply REAL hint logic
      setState(() {
        if (tile.isBomb) {
          tile.isFlagged = true;
          tile.isSafelyRevealed = true;
        } else {
          tile.isRevealed = true;
          tile.isHintRevealed = true;
        }

        game!.hintCount--;

        _showHintDecrease = true;
        isHintMode = false;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showHintDecrease = false;
          });
        }
      });

      await _updateServerGame();
      game!.checkWin();

      if (game!.isGameWon && game!.isGameOver) {
        await _handleGameWin();
      }
      return;
    }

    // === Normal reveal ===
    setState(() {
      game!.reveal(r, c);
    });

    await _updateServerGame();

    if (game!.isGameOver) {
      _inputLocked = true;
      if (game!.isGameWon) {
        await _handleGameWin();
      } else {
        await _finishServerGame(false); // Server: game lost
        await _showBombSequenceAndDialog();
      }
    }
  }

  Future<void> _showBombSequenceAndDialog() async {
    _inputLocked = true;
    List<List<int>> bombPositions = game!.getUnrevealedBombPositions();
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

      setState(() {
        game!.revealBombAt(r, c);
      });

      if (i < bombPositions.length - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      game!.stopBombAnimations();
    });

    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    DialogUtils.showGameOverDialog(
      context: context,
      game: game!,
      onRetry: _restartGame,
    );
  }

  Future<void> _restartGame() async {
    bool isLoss = game!.isGameOver && !game!.isGameWon;
    _isFinishingGame = false; // ← Reset flag
    await _initializeGameFromLevel(currentLevelIndex);
    setState(() {
      _inputLocked = false;
      if (isLoss) game!.winningStreak = 0;
    });
  }

  void _startNextLevel() {
    _isFinishingGame = false; // ← Reset flag
    setState(() {
      _inputLocked = false;
    });

    if (currentLevelIndex + 1 < levels.length) {
      currentLevelIndex++;
      _initializeGameFromLevel(currentLevelIndex);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Congratulations! You finished all levels!')),
      );
      _showStartDialog = true;
      final updatedScore = game!.score;
      game!.finalScore = updatedScore;
    }
  }

  void handleFlag(int r, int c) async {
    if (_inputLocked) return;

    setState(() {
      if (!game!.board[r][c].isRevealed && !game!.isGameOver) {
        if (!game!.board[r][c].isFlagged) {
          if (game!.remainingFlags > 0) {
            game!.board[r][c].isFlagged = true;
            SoundManager.playFlag();
          }
        } else {
          game!.board[r][c].isFlagged = false;
          SoundManager.playUnflag();
        }
        game!.checkWin();
      }
    });

    // Update server after flagging
    await _updateServerGame();

    if (game!.isGameWon && game!.isGameOver) {
      await _handleGameWin(); // ← Only call this, it handles everything
    }
  }

  Future<void> _handleBackToHome() async {
    if (mounted) {
      Navigator.of(context).pop();
    }
    // try {
    //   // Optional: Finish the current game on the server before leaving
    //   // if (serverConnected && serverGameId != null && game != null) {
    //   //   await _finishServerGame(false);
    //   // }

    //   // Navigate back to home screen
    //   if (mounted) {
    //     Navigator.of(context).pop();
    //   }
    // } catch (e) {
    //   // Still navigate back even if server update fails
    //   if (mounted) {
    //     Navigator.of(context).pop();
    //   }
    // }
  }

  void _showWinDialog() {
    DialogUtils.showWinDialog(
      context: context,
      game: game!,
      onNextLevel: _startNextLevel,
    );
  }

  // Responsive game board builder
  Widget _buildGameBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get screen width and ensure no horizontal scrolling
        double screenWidth = MediaQuery.of(context).size.width;
        double availableWidth = screenWidth - 24; // minimal padding

        // Calculate tile size to fit screen width perfectly
        double tileSize =
            (availableWidth - (2 * (game!.cols - 1))) / game!.cols;
        tileSize = tileSize.clamp(20.0, 40.0); // Smaller range for mobile

        double gridWidth = (tileSize * game!.cols) + (2 * (game!.cols - 1));
        double gridHeight = (tileSize * game!.rows) + (2 * (game!.rows - 1));

        return SizedBox(
          width: gridWidth,
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: game!.cols,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: game!.rows * game!.cols,
            itemBuilder: (context, index) {
              final r = index ~/ game!.cols;
              final c = index % game!.cols;
              final tile = game!.board[r][c];
              if (!tile.isActive) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                width: tileSize,
                height: tileSize,
                child: TileWidget(
                  tile: tile,
                  onTap: () => handleTap(r, c),
                  onLongPress: () => handleFlag(r, c),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4E4),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned top bar (Back, Level, Score)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF0B1E3D),
                    ),
                    onPressed: _handleBackToHome,
                    tooltip: 'Back to Home',
                  ),
                  Text(
                    'Level: ${game!.level}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Acsioma',
                      fontSize: 20,
                      color: const Color(0xFF0B1E3D),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Score: ${game!.score}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Acsioma',
                      fontSize: 20,
                      color: const Color(0xFF0B1E3D),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // The rest of the content fills remaining space and is vertically centered
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Compact info row
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Mines count
                              SizedBox(
                                width: 60, // fixed width
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/bombRevealed.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${game!.remainingFlags}',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: const Color(0xFF1B2844),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Streak count
                              SizedBox(
                                width: 60, // fixed width
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/streakIcon.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${game!.winningStreak}',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: const Color(0xFF1B2844),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Hint count
                              SizedBox(
                                width: 60, // fixed width
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/hintButton.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      // allow enough height for the animation
                                      height: 40,
                                      child: Stack(
                                        clipBehavior: Clip
                                            .none, // important! allow overflow
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            '${game!.hintCount}',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: const Color(
                                                    0xFF1B2844,
                                                  ),
                                                ),
                                          ),
                                          if (_showHintDecrease)
                                            Positioned(
                                              top: -20,
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween(
                                                  begin: 1.0,
                                                  end: 0.0,
                                                ),
                                                duration: const Duration(
                                                  milliseconds: 600,
                                                ),
                                                builder:
                                                    (context, value, child) {
                                                      return Opacity(
                                                        opacity: value,
                                                        child: Transform.scale(
                                                          scale: 1.2,
                                                          child: const Text(
                                                            '-1',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 20,
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
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
                            ],
                          ),
                        ),

                        // Game board
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: _buildGameBoard(),
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Hint Button
                              ClickButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed:
                                    (game!.hintCount > 0 && !game!.isGameOver)
                                    ? () async {
                                        setState(() {
                                          isHintMode = !isHintMode;
                                        });
                                        return Future.value();
                                      }
                                    : () async {
                                        return Future.value();
                                      },
                                child: Container(
                                  width: 150, // <-- FIXED WIDTH
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHintMode
                                        ? const Color(0xFF1B2844)
                                        : (game!.hintCount > 0 &&
                                              !game!.isGameOver)
                                        ? Colors.blue.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isHintMode
                                          ? const Color(0xFF1B2844)
                                          : (game!.hintCount > 0 &&
                                                !game!.isGameOver)
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .center, // keep icon + text centered
                                    children: [
                                      Image.asset(
                                        'assets/hintButton.png',
                                        width: 32,
                                        height: 32,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isHintMode ? 'Hint Mode' : 'Use Hint',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isHintMode
                                              ? Colors.white
                                              : (game!.hintCount > 0 &&
                                                        !game!.isGameOver
                                                    ? Colors.blue
                                                    : Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Restart Button
                              ClickButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _restartGame,
                                child: Container(
                                  width: 150,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/restartButton.png',
                                        width: 32,
                                        height: 32,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Restart',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
