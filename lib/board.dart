import 'package:flutter/material.dart';
import 'game.dart';
import 'tile_widget.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  late Game game;

  @override
  void initState() {
    super.initState();
    game = Game(9, 9, 10); // Beginner grid
  }

  void handleTap(int r, int c) {
    setState(() {
      game.reveal(r, c);
    });

    if (game.isGameOver) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(game.isGameWon ? '🎉 You Won!' : '💣 Game Over'),
            content: Text(
              game.isGameWon
                  ? 'Level ${game.level} complete!\nScore: ${game.score}'
                  : 'You hit a mine.\nFinal Score: ${game.score}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    final nextLevel = game.isGameWon
                        ? game.level + 1
                        : game.level;
                    final nextBombs = game.isGameWon
                        ? game.bombs + 1
                        : game.bombs;
                    final nextScore = game.score; // Always preserve score

                    game = Game(
                      9,
                      9,
                      nextBombs,
                      level: nextLevel,
                      score: nextScore,
                    );
                    game.startTimer();
                  });
                },
                child: Text(game.isGameWon ? 'Next Level' : 'Retry'),
              ),
            ],
          ),
        );
      });
    }
  }

  void handleFlag(int r, int c) {
    setState(() {
      if (!game.board[r][c].isRevealed && !game.isGameOver) {
        game.board[r][c].isFlagged = !game.board[r][c].isFlagged;
        game.checkWin(); // This might end the game, which will also trigger UI updates
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // 🧠 Score and level tracker
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '🎯 Level: ${game.level}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '💎 Score: ${game.score}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '💣 Mines left: ${game.remainingFlags}',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: (32 * game.cols) + (2 * (game.cols - 1)),
              height: (32 * game.rows) + (2 * (game.rows - 1)),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: game.cols,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: game.rows * game.cols,
                itemBuilder: (context, index) {
                  final r = index ~/ game.cols;
                  final c = index % game.cols;
                  return TileWidget(
                    tile: game.board[r][c],
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
