import 'package:flutter_test/flutter_test.dart';
import 'package:mine_master/game.dart';
import 'package:mine_master/managers/game_state_manager.dart';
import 'package:mine_master/sound_manager.dart';

// Top-level helper — small game with no bombs.
Game makeBlankGame(int rows, int cols) => Game(rows, cols, 0);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundManager.setSoundEnabled(false);
    SoundManager.setVibrationEnabled(false);
  });

  tearDownAll(() {
    SoundManager.setSoundEnabled(true);
    SoundManager.setVibrationEnabled(true);
  });

  group('GameStateManager — null game', () {
    test('getRevealedCells returns [] when game is null', () {
      final mgr = GameStateManager();
      expect(mgr.getRevealedCells(), isEmpty);
    });

    test('getFlaggedCells returns [] when game is null', () {
      final mgr = GameStateManager();
      expect(mgr.getFlaggedCells(), isEmpty);
    });

    test('getMinePositions returns [] when game is null', () {
      final mgr = GameStateManager();
      expect(mgr.getMinePositions(), isEmpty);
    });
  });

  group('GameStateManager.getRevealedCells', () {
    test('returns empty when no tiles are revealed', () {
      final mgr = GameStateManager()..game = makeBlankGame(2, 2);
      expect(mgr.getRevealedCells(), isEmpty);
    });

    test('returns correct positions for revealed tiles', () {
      final mgr = GameStateManager()..game = makeBlankGame(3, 3);
      mgr.game!.board[0][1].isRevealed = true;
      mgr.game!.board[2][2].isRevealed = true;
      final cells = mgr.getRevealedCells();
      expect(cells.length, 2);
      expect(cells, containsAll([[0, 1], [2, 2]]));
    });

    test('returns all tiles when every tile is revealed', () {
      final mgr = GameStateManager()..game = makeBlankGame(2, 2);
      for (final row in mgr.game!.board) {
        for (final tile in row) {
          tile.isRevealed = true;
        }
      }
      expect(mgr.getRevealedCells().length, 4);
    });
  });

  group('GameStateManager.getFlaggedCells', () {
    test('returns empty when no tiles are flagged', () {
      final mgr = GameStateManager()..game = makeBlankGame(2, 2);
      expect(mgr.getFlaggedCells(), isEmpty);
    });

    test('returns correct positions for flagged tiles', () {
      final mgr = GameStateManager()..game = makeBlankGame(3, 3);
      mgr.game!.board[1][0].isFlagged = true;
      mgr.game!.board[2][1].isFlagged = true;
      final cells = mgr.getFlaggedCells();
      expect(cells.length, 2);
      expect(cells, containsAll([[1, 0], [2, 1]]));
    });
  });

  group('GameStateManager.getMinePositions', () {
    test('returns empty when no bombs on board', () {
      final mgr = GameStateManager()..game = makeBlankGame(3, 3);
      expect(mgr.getMinePositions(), isEmpty);
    });

    test('returns correct positions for all bombs', () {
      final mgr = GameStateManager()..game = makeBlankGame(3, 3);
      mgr.game!.board[0][0].isBomb = true;
      mgr.game!.board[2][2].isBomb = true;
      final mines = mgr.getMinePositions();
      expect(mines.length, 2);
      expect(mines, containsAll([[0, 0], [2, 2]]));
    });

    test('includes revealed bombs', () {
      final mgr = GameStateManager()..game = makeBlankGame(2, 2);
      mgr.game!.board[0][0].isBomb = true;
      mgr.game!.board[0][0].isRevealed = true;
      expect(mgr.getMinePositions().length, 1);
    });
  });

  group('GameStateManager default state', () {
    test('all boolean flags start false', () {
      final mgr = GameStateManager();
      expect(mgr.showStartDialog, isFalse);
      expect(mgr.isHintMode, isFalse);
      expect(mgr.inputLocked, isFalse);
      expect(mgr.isFinishingGame, isFalse);
      expect(mgr.serverConnected, isFalse);
    });

    test('serverGameId starts null', () {
      expect(GameStateManager().serverGameId, isNull);
    });

    test('levels starts empty and currentLevelIndex starts at 0', () {
      final mgr = GameStateManager();
      expect(mgr.levels, isEmpty);
      expect(mgr.currentLevelIndex, 0);
    });
  });
}
