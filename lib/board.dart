import 'package:flutter/material.dart';
import 'game.dart';
import 'tile_widget.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  Game? game; // nullable for loading state

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Optional: simulate a longer load time (remove this line in production)
    await Future.delayed(const Duration(seconds: 1));

    final newGame = Game(9, 9, 10);
    newGame.startTimer();

    setState(() {
      game = newGame;
    });
  }

  void handleTap(int r, int c) {
    setState(() {
      game!.reveal(r, c);
    });

    if (game!.isGameOver) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(game!.isGameWon ? '🎉 You Won!' : '💣 Game Over'),
            content: Text(
              game!.isGameWon
                  ? 'Level ${game!.level} complete!\nScore: ${game!.score}'
                  : 'You hit a mine.\nFinal Score: ${game!.score}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();

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
                  final int updatedHints = won
                      ? game!.hintCount + 1
                      : game!.hintCount;

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
                    game!.startTimer();
                  });

                  if (won && bonus > 0) {
                    Future.delayed(Duration.zero, () {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: AlertDialog(
                            title: const Text("🔥 Winning Streak Bonus!"),
                            content: Text(
                              "You earned a $bonus point bonus for a $newStreak-win streak!",
                            ),
                          ),
                        ),
                      );
                    });
                  }
                },
                child: Text(game!.isGameWon ? 'Next Level' : 'Retry'),
              ),
            ],
          ),
        );
      });
    }
  }

  void handleFlag(int r, int c) {
    setState(() {
      if (!game!.board[r][c].isRevealed && !game!.isGameOver) {
        game!.board[r][c].isFlagged = !game!.board[r][c].isFlagged;
        game!.checkWin();
      }
    });
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '🎯 Level: ${game!.level}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '💎 Score: ${game!.score}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '💣 Mines left: ${game!.remainingFlags}',
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                '🔥 Streak: ${game!.winningStreak}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ElevatedButton(
            onPressed: (game!.hintCount > 0 && !game!.isGameOver)
                ? () {
                    setState(() {
                      final success = game!.useHint();
                      if (success) {
                        game!.hintCount--;
                        game!.checkWin();
                      }
                    });
                  }
                : null,
            child: Text('💡 Use Hint (${game!.hintCount})'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                game = Game(
                  game!.rows,
                  game!.cols,
                  game!.bombs,
                  level: game!.level,
                  score: game!.score,
                  winningStreak: game!.winningStreak,
                  hintCount: game!.hintCount,
                );
                game!.startTimer();
              });
            },
            child: const Text('🔄 Restart Game'),
          ),
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: (32 * game!.cols) + (2 * (game!.cols - 1)),
              height: (32 * game!.rows) + (2 * (game!.rows - 1)),
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
          ),
        ),
      ],
    );
  }
}
