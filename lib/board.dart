import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import 'package:mobile_experiment/sound_manager.dart';
import 'game.dart';
import 'tile_widget.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  Game? game; // nullable for loading state
  bool _showStartDialog = false; // Add this flag
  bool isHintMode = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Optional: simulate a longer load time (remove this line in production)
    await Future.delayed(const Duration(seconds: 1));

    final newGame = Game(9, 9, 10);
    // Don't start timer immediately - wait for user to click Start

    setState(() {
      game = newGame;
      _showStartDialog = true; // Show the start dialog
    });

    // Show start dialog after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showStartDialog) {
        _showGameStartDialog();
      }
    });
  }

  // Add this method to show the start game dialog
  void _showGameStartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must click Start button
      builder: (context) => AlertDialog(
        title: Text(
          'Level '
          '${game!.level}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // _buildStatRow('Level', '${game!.level}'),
            // const SizedBox(height: 12),
            _buildStatRow('Score', '${game!.score}'),
            const SizedBox(height: 12),
            _buildStatRow('Streak', '${game!.winningStreak}'),
            const SizedBox(height: 12),
            _buildStatRow('Hints', '${game!.hintCount}'),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          Center(
            child: ClickButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _showStartDialog = false;
                });
                // Start the timer when user clicks Start
                game!.startTimer();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('START'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build stat rows
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void handleTap(int r, int c) async {
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
      if (game!.isGameWon) {
        Future.delayed(Duration.zero, () {
          _showWinDialog();
        });
      } else {
        await _showBombSequenceAndDialog();
      }
    }
  }

  Future<void> _showBombSequenceAndDialog() async {
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
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            '💣 Game Over',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            'You hit a mine.\nFinal Score: ${game!.score}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            ClickButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartGame();
              },
              child: Text(
                'Retry',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }
  }

  // Update the restart button onPressed to also show the dialog
  void _restartGame() {
    // Check if this is a loss (game over but not won) to reset streak
    bool isLoss = game!.isGameOver && !game!.isGameWon;

    setState(() {
      game = Game(
        game!.rows,
        game!.cols,
        game!.bombs,
        level: game!.level,
        score: game!.score,
        winningStreak: isLoss
            ? 0
            : game!.winningStreak, // Reset streak to 0 if lost
        hintCount: game!.hintCount,
      );
      _showStartDialog = true;
    });

    // Show start dialog for restart too
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showStartDialog) {
        _showGameStartDialog();
      }
    });
  }

  // Update the "Next Level" logic to also show the dialog
  void _startNextLevel() {
    final bool won = game!.isGameWon;
    final int newStreak = won ? game!.winningStreak + 1 : 0;

    int base = 100;
    int bonus = 0;
    int updatedScore = game!.score;

    if (won && newStreak >= 2) {
      bonus = (base * (newStreak * 0.1)).round();
      updatedScore += base + bonus;
    } else if (won) {
      updatedScore += base;
    }

    final int updatedStreak = won ? newStreak : 0;
    final int updatedHints = won ? game!.hintCount + 1 : game!.hintCount;

    setState(() {
      game = Game(
        9,
        9,
        won ? game!.bombs + 1 : game!.bombs,
        level: won ? game!.level + 1 : game!.level,
        score: updatedScore,
        winningStreak: updatedStreak,
        hintCount: updatedHints,
      );
      _showStartDialog = true;
    });

    // Show start dialog for next level
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showStartDialog) {
        _showGameStartDialog();
      }
    });

    // Show bonus dialog if applicable
    if (won && bonus > 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: AlertDialog(
              title: Text(
                "🔥 Winning Streak Bonus!",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Text(
                "You earned a $bonus point bonus for a $newStreak-win streak!",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        );
      });
    }
  }

  void handleFlag(int r, int c) {
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
      Future.delayed(Duration.zero, () {
        _showWinDialog();
      });
    }
  }

  // Add this method to show win dialog
  void _showWinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '🎉 You Won!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Level ${game!.level} complete!\nScore: ${game!.score}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          ClickButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNextLevel();
            },
            child: Text(
              'Next Level',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
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
                  width: (42 * game!.cols) + (2 * (game!.cols - 1)),
                  height: (42 * game!.rows) + (2 * (game!.rows - 1)),
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
                      return TileWidget(
                        tile: game!.board[r][c],
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
