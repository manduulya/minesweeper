import '../game.dart';

class GameStateManager {
  Game? game;
  bool showStartDialog = false;
  bool isHintMode = false;
  bool inputLocked = false;
  bool isFinishingGame = false;
  bool showHintDecrease = false;

  int? serverGameId;
  DateTime? gameStartTime;
  bool serverConnected = false;

  List<Map<String, dynamic>> levels = [];
  int currentLevelIndex = 0;

  List<List<int>> getRevealedCells() {
    if (game == null) return [];
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

  List<List<int>> getFlaggedCells() {
    if (game == null) return [];
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

  List<List<int>> getMinePositions() {
    if (game == null) return [];
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
}
