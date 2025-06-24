import 'dart:math';
import 'tile.dart';

class Game {
  final int rows;
  final int cols;
  final int bombCount;
  int get bombs => bombCount;
  late List<List<Tile>> board;
  bool isGameOver = false;
  bool isGameWon = false; // Optional for future
  int level;
  int score;
  DateTime? startTime;
  DateTime? endTime;
  int winningStreak;
  int hintCount;

  void startTimer() {
    startTime = DateTime.now();
  }

  void stopTimer() {
    endTime = DateTime.now();
  }

  int get remainingFlags {
    int flags = 0;
    for (var row in board) {
      for (var tile in row) {
        if (tile.isFlagged) flags++;
      }
    }
    return bombCount - flags;
  }

  int calculateBonus() {
    if (startTime == null || endTime == null) return 0;
    final seconds = endTime!.difference(startTime!).inSeconds;
    return (30 - seconds).clamp(0, 30); // Bonus if completed under 30 sec
  }

  Game(
    this.rows,
    this.cols,
    this.bombCount, {
    this.level = 1,
    this.score = 0,
    this.winningStreak = 0,
    this.hintCount = 3,
  }) {
    _initBoard();
    _placeBombs();
    _calculateAdjacency();
  }

  void _initBoard() {
    board = List.generate(rows, (_) => List.generate(cols, (_) => Tile()));
  }

  void _placeBombs() {
    final rand = Random();
    int placed = 0;
    while (placed < bombCount) {
      final r = rand.nextInt(rows);
      final c = rand.nextInt(cols);
      if (!board[r][c].isBomb) {
        board[r][c].isBomb = true;
        placed++;
      }
    }
  }

  void _calculateAdjacency() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c].isBomb) continue;
        int count = 0;
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            final nr = r + i;
            final nc = c + j;
            if (nr >= 0 &&
                nr < rows &&
                nc >= 0 &&
                nc < cols &&
                board[nr][nc].isBomb) {
              count++;
            }
          }
        }
        board[r][c].adjacentBombs = count;
      }
    }
  }

  void reveal(int r, int c) {
    if (isGameOver || board[r][c].isRevealed || board[r][c].isFlagged) return;

    board[r][c].isRevealed = true;

    if (board[r][c].isBomb) {
      isGameOver = true;
      _revealAll();
      return;
    }

    if (board[r][c].adjacentBombs == 0) {
      for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
          int nr = r + i, nc = c + j;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            reveal(nr, nc);
          }
        }
      }
    }

    checkWin(); // Check win after revealing
  }

  void _revealAll() {
    for (var row in board) {
      for (var tile in row) {
        tile.isRevealed = true;
      }
    }
  }

  bool checkWin() {
    bool allSafeTilesRevealed = true;
    bool allBombsFlaggedCorrectly = true;

    for (var row in board) {
      for (var tile in row) {
        if (!tile.isBomb && !tile.isRevealed) allSafeTilesRevealed = false;
        if (tile.isBomb && !tile.isFlagged) allBombsFlaggedCorrectly = false;
        if (!tile.isBomb && tile.isFlagged) allBombsFlaggedCorrectly = false;
      }
    }

    if (allSafeTilesRevealed || allBombsFlaggedCorrectly) {
      stopTimer();
      isGameOver = true;
      isGameWon = true;

      return true;
    }

    return false;
  }

  bool useHint() {
    if (hintCount <= 0 || isGameOver) return false;

    for (var row in board) {
      for (var tile in row) {
        if (!tile.isRevealed && !tile.isBomb && !tile.isFlagged) {
          tile.isRevealed = true;
          return true;
        }
      }
    }
    return false;
  }
}
