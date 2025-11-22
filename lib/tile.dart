class Tile {
  bool isRevealed = false;
  bool isBomb = false;
  bool isFlagged = false;
  int adjacentBombs = 0;
  bool isHintRevealed = false;
  bool isSafelyRevealed = false;
  bool shouldAnimate = false;
  bool isActive = true;
  bool isHintAnimating = false;
  String? hintFrame; // "flag", "question", "exclamation", "safe"
}
