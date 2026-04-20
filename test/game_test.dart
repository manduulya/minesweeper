import 'package:flutter_test/flutter_test.dart';
import 'package:mine_master/game.dart';
import 'package:mine_master/sound_manager.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [Game] with the right [bombCount] but immediately resets every
/// tile so the board is blank. Callers place bombs at explicit positions and
/// call [game.calculateAdjacency()] when needed.
Game _blankGame(int rows, int cols, int bombCount) {
  final game = Game(rows, cols, bombCount);
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final t = game.board[r][c];
      t.isBomb = false;
      t.isRevealed = false;
      t.isFlagged = false;
      t.adjacentBombs = 0;
      t.isSafelyRevealed = false;
      t.shouldAnimate = false;
      t.isHintRevealed = false;
    }
  }
  return game;
}

/// Places a bomb at (r, c) and recalculates adjacency for the whole board.
void _plantBomb(Game game, int r, int c) {
  game.board[r][c].isBomb = true;
  game.calculateAdjacency();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Silence audio + vibration so platform-channel calls in SoundManager
    // are no-ops during tests.
    SoundManager.setSoundEnabled(false);
    SoundManager.setVibrationEnabled(false);
  });

  tearDownAll(() {
    SoundManager.setSoundEnabled(true);
    SoundManager.setVibrationEnabled(true);
  });

  // ── Construction ──────────────────────────────────────────────────────────

  group('Game construction', () {
    test('board has the requested dimensions', () {
      final game = Game(4, 7, 0);
      expect(game.board.length, 4);
      expect(game.board[0].length, 7);
    });

    test('bombCount is reflected in the bombs getter', () {
      final game = Game(5, 5, 3);
      expect(game.bombs, 3);
    });

    test('exactly bombCount tiles are marked as bombs', () {
      final game = Game(5, 5, 5);
      int count = 0;
      for (final row in game.board) {
        for (final tile in row) {
          if (tile.isBomb) count++;
        }
      }
      expect(count, 5);
    });

    test('all tiles are active when no shape is supplied', () {
      final game = Game(3, 3, 0);
      for (final row in game.board) {
        for (final tile in row) {
          expect(tile.isActive, isTrue);
        }
      }
    });

    test('only shape-flagged tiles are active', () {
      final shape = [
        [1, 0],
        [0, 1],
      ];
      final game = Game(2, 2, 0, shape: shape);
      expect(game.board[0][0].isActive, isTrue);
      expect(game.board[0][1].isActive, isFalse);
      expect(game.board[1][0].isActive, isFalse);
      expect(game.board[1][1].isActive, isTrue);
    });

    test('defaults: level 1, score 0, winningStreak 0, hintCount 3', () {
      final game = Game(3, 3, 0);
      expect(game.level, 1);
      expect(game.score, 0);
      expect(game.winningStreak, 0);
      expect(game.hintCount, 3);
    });

    test('named params override defaults', () {
      final game =
          Game(3, 3, 0, level: 5, score: 200, winningStreak: 3, hintCount: 7);
      expect(game.level, 5);
      expect(game.score, 200);
      expect(game.winningStreak, 3);
      expect(game.hintCount, 7);
    });

    test('bombs are never placed on inactive shape tiles', () {
      // Narrow single-row shape so all active tiles can hold the bomb.
      final shape = [
        [1, 1, 1, 1, 1],
        [0, 0, 0, 0, 0],
      ];
      final game = Game(2, 5, 3, shape: shape);
      for (int c = 0; c < 5; c++) {
        expect(game.board[1][c].isBomb, isFalse);
      }
    });
  });

  // ── calculateAdjacency ───────────────────────────────────────────────────

  group('calculateAdjacency', () {
    test('isolated bomb — surrounding tiles each get count 1', () {
      // 3x3, bomb in the centre — all 8 neighbours get count 1.
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 1, 1);
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          if (r == 1 && c == 1) continue; // the bomb itself
          expect(game.board[r][c].adjacentBombs, 1,
              reason: 'tile ($r,$c) should have adjacentBombs == 1');
        }
      }
    });

    test('bomb tiles keep adjacentBombs == 0', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      expect(game.board[0][0].adjacentBombs, 0);
    });

    test('corner bomb touches exactly 3 neighbours', () {
      // Bomb at (0,0) in a 3x3 — only (0,1), (1,0), (1,1) are adjacent.
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      int affected = 0;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          if (!game.board[r][c].isBomb && game.board[r][c].adjacentBombs > 0) {
            affected++;
          }
        }
      }
      expect(affected, 3);
    });

    test('tile surrounded by 8 bombs gets adjacentBombs == 8', () {
      // Place 8 bombs around the centre of a 3x3.
      final game = _blankGame(3, 3, 8);
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          if (r != 1 || c != 1) game.board[r][c].isBomb = true;
        }
      }
      game.calculateAdjacency();
      expect(game.board[1][1].adjacentBombs, 8);
    });

    test('two adjacent bombs — shared neighbour gets count 2', () {
      // Bombs at (0,0) and (0,2); tile at (0,1) is between them.
      final game = _blankGame(1, 3, 2);
      game.board[0][0].isBomb = true;
      game.board[0][2].isBomb = true;
      game.calculateAdjacency();
      expect(game.board[0][1].adjacentBombs, 2);
    });
  });

  // ── reveal ───────────────────────────────────────────────────────────────

  group('reveal', () {
    test('revealing a safe tile marks it as revealed', () {
      final game = _blankGame(3, 3, 0);
      game.board[1][1].adjacentBombs = 1; // prevent cascade
      game.reveal(1, 1);
      expect(game.board[1][1].isRevealed, isTrue);
    });

    test('revealing a bomb sets isGameOver and keeps isGameWon false', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      game.reveal(0, 0);
      expect(game.isGameOver, isTrue);
      expect(game.isGameWon, isFalse);
    });

    test('revealing a bomb does not cascade', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 1, 1);
      game.reveal(1, 1);
      int revealedCount = 0;
      for (final row in game.board) {
        for (final tile in row) {
          if (tile.isRevealed) revealedCount++;
        }
      }
      // Only the bomb tile itself is revealed.
      expect(revealedCount, 1);
    });

    test('revealing an already-revealed tile does nothing extra', () {
      // 2×2 board with 1 unflagged bomb — checkWin cannot fire, so
      // isGameOver stays false throughout.
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 1, 1); // bomb at (1,1), so (0,0) has adjacentBombs==1
      game.reveal(0, 0);
      expect(game.board[0][0].isRevealed, isTrue);
      expect(game.isGameOver, isFalse);
      // Reveal the same tile again — must be a no-op.
      game.reveal(0, 0);
      expect(game.isGameOver, isFalse);
    });

    test('revealing a flagged tile does nothing', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      game.reveal(0, 0);
      expect(game.board[0][0].isRevealed, isFalse);
      expect(game.isGameOver, isFalse);
    });

    test('reveal does nothing once isGameOver is set', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.reveal(0, 0); // sets isGameOver
      expect(game.isGameOver, isTrue);
      game.reveal(1, 1); // should be ignored
      expect(game.board[1][1].isRevealed, isFalse);
    });

    test('safe tile with adjacentBombs > 0 does not cascade', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      // Tile (1,1) has adjacentBombs == 1; revealing it should NOT cascade.
      game.reveal(1, 1);
      int revealedCount = 0;
      for (final row in game.board) {
        for (final tile in row) {
          if (tile.isRevealed) revealedCount++;
        }
      }
      expect(revealedCount, 1);
    });

    test('revealing a 0-adjacent tile cascades to all connected safe tiles',
        () {
      // 1×5 board, no bombs — all adjacentBombs == 0.
      final game = _blankGame(1, 5, 0);
      game.reveal(0, 0);
      for (int c = 0; c < 5; c++) {
        expect(game.board[0][c].isRevealed, isTrue,
            reason: 'tile (0,$c) should be revealed by cascade');
      }
    });

    test('cascade stops at tiles adjacent to a bomb', () {
      // 1×4 board, bomb at (0,3). Tile (0,2) has adjacentBombs==1 so cascade
      // from (0,0) should stop before it (exclusive).
      final game = _blankGame(1, 4, 1);
      _plantBomb(game, 0, 3);
      // (0,2) adjacentBombs == 1 — it IS revealed by the cascade (tile is
      // safe), but the cascade doesn't continue past it.
      game.reveal(0, 0);
      // (0,3) is a bomb — must NOT be auto-revealed.
      expect(game.board[0][3].isRevealed, isFalse);
      expect(game.isGameOver, isFalse);
    });

    test('cascade does not reveal flagged tiles', () {
      final game = _blankGame(1, 3, 0);
      game.board[0][1].isFlagged = true;
      game.reveal(0, 0);
      expect(game.board[0][1].isRevealed, isFalse);
    });

    test('finalScore is set to score when game is lost', () {
      final game = _blankGame(2, 2, 1);
      game.score = 150; // simulated prior progress
      _plantBomb(game, 0, 0);
      game.reveal(0, 0);
      expect(game.finalScore, 150);
    });
  });

  // ── checkWin ─────────────────────────────────────────────────────────────

  group('checkWin', () {
    test('returns false when a bomb is not flagged', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      // Reveal all safe tiles but do not flag the bomb.
      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 2; c++) {
          if (!game.board[r][c].isBomb) game.board[r][c].isRevealed = true;
        }
      }
      expect(game.checkWin(), isFalse);
    });

    test('returns true when all bombs are correctly flagged', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      expect(game.checkWin(), isTrue);
    });

    test('returns false when a non-bomb tile is flagged', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true; // correct flag
      game.board[0][1].isFlagged = true; // wrong flag
      expect(game.checkWin(), isFalse);
    });

    test('safelyRevealed bomb counts as handled — no flag needed', () {
      // 2×2 board, 1 bomb that has been safely revealed via hint.
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isSafelyRevealed = true;
      // No flag placed — should still win because safelyRevealedBombs covers it.
      expect(game.checkWin(), isTrue);
    });

    test('win increments winningStreak by 1', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      final before = game.winningStreak;
      game.checkWin();
      expect(game.winningStreak, before + 1);
    });

    test('win increments hintCount by 1', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      final before = game.hintCount;
      game.checkWin();
      expect(game.hintCount, before + 1);
    });

    test('win adds 100 base points to score', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      final before = game.score;
      game.checkWin();
      // With winningStreak == 0 before win → streak becomes 1 → no bonus.
      expect(game.score, before + 100);
    });

    test('win sets isGameOver and isGameWon', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      game.checkWin();
      expect(game.isGameOver, isTrue);
      expect(game.isGameWon, isTrue);
    });

    test('bonus is 0 for first win (streak 0 → 1)', () {
      final game = _blankGame(2, 2, 1, );
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      game.checkWin();
      expect(game.bonus, 0);
    });

    test('bonus is applied for streak >= 2', () {
      final game = _blankGame(2, 2, 1);
      game.winningStreak = 1; // one previous win
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      game.checkWin(); // streak becomes 2
      // bonus = (100 * (2 * 0.1)).round() = 20
      expect(game.bonus, 20);
      expect(game.score, greaterThan(100));
    });

    test('finalScore equals score after win', () {
      final game = _blankGame(2, 2, 1);
      game.score = 300;
      _plantBomb(game, 0, 0);
      game.board[0][0].isFlagged = true;
      game.checkWin();
      expect(game.finalScore, game.score);
    });
  });

  // ── remainingFlags ────────────────────────────────────────────────────────

  group('remainingFlags', () {
    test('equals bombCount when no flags placed', () {
      final game = _blankGame(3, 3, 2);
      _plantBomb(game, 0, 0);
      game.board[1][1].isBomb = true;
      game.calculateAdjacency();
      expect(game.remainingFlags, 2);
    });

    test('decreases by 1 for each flagged bomb', () {
      final game = _blankGame(3, 3, 2);
      _plantBomb(game, 0, 0);
      game.board[1][1].isBomb = true;
      game.calculateAdjacency();
      game.board[0][0].isFlagged = true;
      expect(game.remainingFlags, 1);
    });

    test('hint-revealed bombs do not reduce remainingFlags count', () {
      // safelyRevealed bomb should be excluded from the effective bomb count.
      final game = _blankGame(3, 3, 2);
      game.board[0][0].isBomb = true;
      game.board[1][1].isBomb = true;
      game.calculateAdjacency();
      game.board[0][0].isSafelyRevealed = true;
      // Only 1 bomb needs flagging now.
      expect(game.remainingFlags, 1);
    });

    test('incorrectly flagged safe tile still counts as a used flag', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      game.board[1][1].isFlagged = true; // wrong flag
      // remainingFlags = bombCount(1) - userFlags(1) = 0
      expect(game.remainingFlags, 0);
    });
  });

  // ── calculateBonus ────────────────────────────────────────────────────────

  group('calculateBonus', () {
    test('returns 0 when timer was never started', () {
      final game = _blankGame(2, 2, 0);
      expect(game.calculateBonus(), 0);
    });

    test('returns 0 when only startTime is set', () {
      final game = _blankGame(2, 2, 0);
      game.startTimer();
      expect(game.calculateBonus(), 0);
    });

    test('returns time-based bonus for completion under 30 seconds', () {
      final game = _blankGame(2, 2, 0);
      game.startTime = DateTime.now().subtract(const Duration(seconds: 10));
      game.endTime = DateTime.now();
      // bonus = (30 - 10).clamp(0, 30) = 20
      expect(game.calculateBonus(), 20);
    });

    test('returns 30 for near-instant completion', () {
      final game = _blankGame(2, 2, 0);
      game.startTime = DateTime.now();
      game.endTime = DateTime.now();
      expect(game.calculateBonus(), 30);
    });

    test('returns 0 for completion over 30 seconds', () {
      final game = _blankGame(2, 2, 0);
      game.startTime = DateTime.now().subtract(const Duration(seconds: 60));
      game.endTime = DateTime.now();
      expect(game.calculateBonus(), 0);
    });
  });

  // ── getUnrevealedBombPositions ────────────────────────────────────────────

  group('getUnrevealedBombPositions', () {
    test('returns all bomb positions when none are revealed', () {
      final game = _blankGame(3, 3, 2);
      game.board[0][0].isBomb = true;
      game.board[2][2].isBomb = true;
      game.calculateAdjacency();
      final positions = game.getUnrevealedBombPositions();
      expect(positions.length, 2);
      expect(positions, containsAll([[0, 0], [2, 2]]));
    });

    test('excludes already-revealed bombs', () {
      final game = _blankGame(3, 3, 2);
      game.board[0][0].isBomb = true;
      game.board[2][2].isBomb = true;
      game.board[0][0].isRevealed = true; // already revealed
      game.calculateAdjacency();
      final positions = game.getUnrevealedBombPositions();
      expect(positions.length, 1);
      expect(positions.first, [2, 2]);
    });

    test('returns empty list when all bombs are revealed', () {
      final game = _blankGame(2, 2, 1);
      _plantBomb(game, 0, 0);
      game.board[0][0].isRevealed = true;
      expect(game.getUnrevealedBombPositions(), isEmpty);
    });
  });

  // ── revealBombAt / stopBombAnimations ─────────────────────────────────────

  group('revealBombAt', () {
    test('sets isRevealed and shouldAnimate on the target bomb', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 1, 1);
      game.revealBombAt(1, 1);
      expect(game.board[1][1].isRevealed, isTrue);
      expect(game.board[1][1].shouldAnimate, isTrue);
    });

    test('does nothing to a non-bomb tile', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      game.revealBombAt(1, 1); // safe tile
      expect(game.board[1][1].isRevealed, isFalse);
      expect(game.board[1][1].shouldAnimate, isFalse);
    });
  });

  group('stopBombAnimations', () {
    test('clears shouldAnimate on every bomb', () {
      final game = _blankGame(3, 3, 2);
      game.board[0][0].isBomb = true;
      game.board[1][1].isBomb = true;
      game.board[0][0].shouldAnimate = true;
      game.board[1][1].shouldAnimate = true;
      game.calculateAdjacency();
      game.stopBombAnimations();
      expect(game.board[0][0].shouldAnimate, isFalse);
      expect(game.board[1][1].shouldAnimate, isFalse);
    });

    test('does not affect non-bomb tiles', () {
      final game = _blankGame(3, 3, 1);
      _plantBomb(game, 0, 0);
      game.board[1][1].shouldAnimate = true; // safe tile
      game.stopBombAnimations();
      expect(game.board[1][1].shouldAnimate, isTrue);
    });
  });
}
