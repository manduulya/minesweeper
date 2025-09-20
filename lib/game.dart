import 'dart:math';
import 'package:mobile_experiment/sound_manager.dart';
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
  int bonus = 0;
  int finalScore = 0;
  DateTime? startTime;
  DateTime? endTime;
  int winningStreak;
  int hintCount;
  final List<List<int>>? shape;

  void startTimer() {
    startTime = DateTime.now();
  }

  void stopTimer() {
    endTime = DateTime.now();
  }

  int get remainingFlags {
    int currentFlags = 0;
    int safelyRevealedBombs = 0;

    for (var row in board) {
      for (var tile in row) {
        if (tile.isFlagged) currentFlags++;
        if (tile.isBomb && tile.isSafelyRevealed) safelyRevealedBombs++;
      }
    }

    // Effective bomb count = original bomb count - safely revealed bombs
    int effectiveBombCount = bombCount - safelyRevealedBombs;

    // Remaining flags needed = effective bombs - currently placed flags
    return effectiveBombCount - currentFlags;
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
    this.shape,
  }) {
    _initBoard();
    _placeBombs();
    _calculateAdjacency();
  }

  void _initBoard() {
    board = List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        final tile = Tile();
        // Mark tile as active/inactive based on shape
        tile.isActive = shape == null ? true : shape![r][c] == 1;
        return tile;
      }),
    );
  }

  void _placeBombs() {
    final rand = Random();
    int placed = 0;
    while (placed < bombCount) {
      final r = rand.nextInt(rows);
      final c = rand.nextInt(cols);
      if (board[r][c].isActive && !board[r][c].isBomb) {
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
      SoundManager.playLost();
      isGameOver = true;
      finalScore = score;
      // Don't reveal all immediately - let the UI handle the animation
      return;
    }

    SoundManager.playReveal();

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

  // Get list of all unrevealed bomb positions
  List<List<int>> getUnrevealedBombPositions() {
    List<List<int>> bombPositions = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c].isBomb && !board[r][c].isRevealed) {
          bombPositions.add([r, c]);
        }
      }
    }
    return bombPositions;
  }

  // Method to reveal a specific bomb with animation
  void revealBombAt(int r, int c) {
    if (board[r][c].isBomb) {
      board[r][c].isRevealed = true;
      board[r][c].shouldAnimate = true;
    }
  }

  // Method to stop bomb animations
  void stopBombAnimations() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c].isBomb) {
          board[r][c].shouldAnimate = false;
        }
      }
    }
  }

  // In Game class - Updated checkWin method
  bool checkWin() {
    // Count safely revealed bombs (revealed by hints)
    int safelyRevealedBombs = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final tile = board[r][c];
        if (tile.isBomb && tile.isSafelyRevealed) {
          safelyRevealedBombs++;
        }
      }
    }

    // Calculate remaining bombs that need to be flagged
    int remainingBombs = bombCount - safelyRevealedBombs;

    // Check if all remaining bombs are correctly flagged and no non-bombs are flagged
    bool allRemainingBombsFlagged = true;
    bool noIncorrectFlags = true;
    int flaggedBombs = 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final tile = board[r][c];

        // If it's a bomb that's not safely revealed and not flagged, we haven't won yet
        if (tile.isBomb && !tile.isSafelyRevealed && !tile.isFlagged) {
          allRemainingBombsFlagged = false;
        }

        // Count flagged bombs (excluding safely revealed ones)
        if (tile.isBomb && !tile.isSafelyRevealed && tile.isFlagged) {
          flaggedBombs++;
        }

        // If it's not a bomb but is flagged, that's incorrect
        if (!tile.isBomb && tile.isFlagged) {
          noIncorrectFlags = false;
        }
      }
    }

    // Win if all remaining bombs are flagged and no incorrect flags
    if (allRemainingBombsFlagged &&
        noIncorrectFlags &&
        flaggedBombs == remainingBombs) {
      stopTimer();
      isGameOver = true;
      isGameWon = true;
      SoundManager.playWon();
      int base = 100;
      winningStreak += 1;
      hintCount += 1;
      bonus = (winningStreak >= 2) ? (base * (winningStreak * 0.1)).round() : 0;
      score += base + bonus;
      finalScore = score;
      return true;
    }
    return false;
  }

  // Updated remainingFlags getter to account for safely revealed bombs
  bool useHint() {
    if (isGameOver) return false;

    for (var row in board) {
      for (var tile in row) {
        if (!tile.isRevealed && !tile.isBomb && !tile.isFlagged) {
          tile.isRevealed = true;
          tile.isHintRevealed = true;
          return true;
        }
      }
    }
    return false;
  }
}
