import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import 'package:mobile_experiment/sound_manager.dart';
import 'game.dart';
import 'tile_widget.dart';
import './dialog_utils/dialog_utils.dart';
import 'levels/levels_loader.dart';

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

  List<Map<String, dynamic>> levels = [];
  int currentLevelIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLevelsAndStart();
  }

  Future<void> _loadLevelsAndStart() async {
    levels = await loadLevels();
    currentLevelIndex = 0;
    _initializeGameFromLevel(currentLevelIndex);
  }

  void _initializeGameFromLevel(int levelIdx) {
    final levelData = levels[levelIdx];
    final newGame = Game(
      levelData['rows'],
      levelData['cols'],
      levelData['bombs'],
      level: levelData['level'],
      score: game?.score ?? 0,
      winningStreak: game?.winningStreak ?? 0,
      hintCount: game?.hintCount ?? 3,
      shape: (levelData['shape'] as List)
          .map((row) => (row as List).map((e) => e as int).toList())
          .toList(),
    );
    setState(() {
      game = newGame;
      _showStartDialog = true;
    });
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (_showStartDialog) {
    //     _showGameStartDialog();
    //   }
    // });
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
    if (isHintMode &&
        !game!.board[r][c].isRevealed &&
        !game!.board[r][c].isFlagged) {
      setState(() {
        game!.board[r][c].isRevealed = true;
        game!.board[r][c].isHintRevealed = true; // mark it as hint
        game!.hintCount--; // consume a hint
        isHintMode = false; // exit hint mode

        // If it's a bomb revealed by hint, mark it as safely revealed
        if (game!.board[r][c].isBomb) {
          game!.board[r][c].isSafelyRevealed = true;
          // Play a different sound for safely revealed bombs
          // SoundManager.playHint(); // or create a special bomb-hint sound
        }
      });

      game!.checkWin();

      // Check for win immediately after hint reveal and show dialog
      if (game!.isGameWon && game!.isGameOver) {
        game!.finalScore = game!.score;
        Future.delayed(Duration.zero, () {
          _showWinDialog();
        });
      }

      return; // don't run normal reveal
    }

    // Normal reveal
    setState(() {
      game!.reveal(r, c);
    });

    if (game!.isGameOver) {
      _inputLocked = true;
      if (game!.isGameWon) {
        game!.finalScore = game!.score;
        Future.delayed(Duration.zero, () {
          _showWinDialog();
        });
      } else {
        await _showBombSequenceAndDialog();
      }
    }
  }

  Future<void> _showBombSequenceAndDialog() async {
    _inputLocked = true;
    // Get all unrevealed bomb positions and shuffle them
    List<List<int>> bombPositions = game!.getUnrevealedBombPositions();
    bombPositions.shuffle(); // Randomize the order

    if (bombPositions.isEmpty) {
      // If no unrevealed bombs, show dialog immediately
      _showGameOverDialog();
      return;
    }

    // Calculate delay between each bomb reveal (1 second total)
    int totalBombs = bombPositions.length;
    int delayMs = totalBombs > 1 ? (1000 / totalBombs).round() : 1000;

    // Reveal bombs one by one
    for (int i = 0; i < bombPositions.length; i++) {
      int r = bombPositions[i][0];
      int c = bombPositions[i][1];

      setState(() {
        game!.revealBombAt(r, c);
      });

      // Wait before revealing next bomb (except for the last one)
      if (i < bombPositions.length - 1) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    // Hold for 1 more second after all bombs are revealed
    await Future.delayed(const Duration(seconds: 1));

    // Stop all animations
    setState(() {
      game!.stopBombAnimations();
    });

    // Show the game over dialog
    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    DialogUtils.showGameOverDialog(
      context: context,
      game: game!,
      onRetry: _restartGame,
    );
  }

  // Update the restart button onPressed to also show the dialog
  void _restartGame() {
    // Check if this is a loss (game over but not won) to reset streak
    bool isLoss = game!.isGameOver && !game!.isGameWon;
    _initializeGameFromLevel(currentLevelIndex);
    setState(() {
      _inputLocked = false;
      if (isLoss) game!.winningStreak = 0;
    });
  }

  void _startNextLevel() {
    setState(() {
      _inputLocked = false;
    });
    if (currentLevelIndex + 1 < levels.length) {
      currentLevelIndex++;
      _initializeGameFromLevel(currentLevelIndex);
    } else {
      // Optionally show a "You finished all levels!" dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Congratulations! You finished all levels!')),
      );
      _showStartDialog = true;
      final updatedScore = game!.score;
      game!.finalScore = updatedScore;
    }
  }

  void handleFlag(int r, int c) {
    if (_inputLocked) return;
    setState(() {
      if (!game!.board[r][c].isRevealed && !game!.isGameOver) {
        // If trying to flag a tile
        if (!game!.board[r][c].isFlagged) {
          // Only allow flagging if we have remaining flags
          if (game!.remainingFlags > 0) {
            game!.board[r][c].isFlagged = true;
            SoundManager.playFlag();
          }
        } else {
          // Always allow unflagging
          game!.board[r][c].isFlagged = false;
          SoundManager.playUnflag();
        }
        game!.checkWin();
      }
    });

    // Check for win immediately after flagging and show dialog
    if (game!.isGameWon && game!.isGameOver) {
      game!.finalScore = game!.score; // store final score
      Future.delayed(Duration.zero, () {
        _showWinDialog();
      });
    }
  }

  void _showWinDialog() {
    DialogUtils.showWinDialog(
      context: context,
      game: game!,
      onNextLevel: _startNextLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return const Center(
        child: CircularProgressIndicator(), // ⏳ Show loading screen
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Score and Level in top left corner (vertical)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level: ${game!.level}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Acsioma',
                      fontSize: 26,
                    ),
                  ),
                  Text(
                    'Score: ${game!.score}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Acsioma',
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
              const Spacer(), // Pushes the score/level to the left
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Streak and Bomb icons above the board (same size as bottom buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/bombRevealed.png',
                            width: 50, // Same size as buttons below
                            height: 50,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'x ${game!.remainingFlags}',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Image.asset(
                            'assets/streakIcon.png',
                            width: 50, // Same size as buttons below
                            height: 50,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'x ${game!.winningStreak}',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Game board
                SizedBox(
                  width: (40 * game!.cols) + (2 * (game!.cols - 1)),
                  height: (40 * game!.rows) + (2 * (game!.rows - 1)),
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
                        return const SizedBox.shrink(); // Hide inactive tiles
                      }
                      return TileWidget(
                        tile: tile,
                        onTap: () => handleTap(r, c),
                        onLongPress: () => handleFlag(r, c),
                      );
                    },
                  ),
                ),

                // Hint and Restart buttons below the board
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Use Hint Button
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
                        onPressed: (game!.hintCount > 0 && !game!.isGameOver)
                            ? () {
                                setState(() {
                                  // final success = game!.useHint();
                                  // if (success) {
                                  //   game!.hintCount--;
                                  //   game!.checkWin();
                                  // }
                                  isHintMode = true; // enable hint mode
                                });
                              }
                            : () {},
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/hintButton.png',
                              width: 50,
                              height: 50,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'x ${game!.hintCount}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
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
                        onPressed: _restartGame, // Use the new method
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/restartButton.png',
                              width: 50,
                              height: 50,
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
        ),
      ],
    );
  }
}
