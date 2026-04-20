import 'package:flutter_test/flutter_test.dart';
import 'package:mine_master/tile.dart';

void main() {
  group('Tile', () {
    test('initialises with correct defaults', () {
      final tile = Tile();
      expect(tile.isRevealed, isFalse);
      expect(tile.isBomb, isFalse);
      expect(tile.isFlagged, isFalse);
      expect(tile.adjacentBombs, 0);
      expect(tile.isHintRevealed, isFalse);
      expect(tile.isSafelyRevealed, isFalse);
      expect(tile.shouldAnimate, isFalse);
      expect(tile.isActive, isTrue);
      expect(tile.isHintAnimating, isFalse);
      expect(tile.hintFrame, isNull);
    });

    test('all properties can be mutated independently', () {
      final tile = Tile();

      tile.isRevealed = true;
      expect(tile.isRevealed, isTrue);

      tile.isBomb = true;
      expect(tile.isBomb, isTrue);

      tile.isFlagged = true;
      expect(tile.isFlagged, isTrue);

      tile.adjacentBombs = 5;
      expect(tile.adjacentBombs, 5);

      tile.isHintRevealed = true;
      expect(tile.isHintRevealed, isTrue);

      tile.isSafelyRevealed = true;
      expect(tile.isSafelyRevealed, isTrue);

      tile.shouldAnimate = true;
      expect(tile.shouldAnimate, isTrue);

      tile.isActive = false;
      expect(tile.isActive, isFalse);

      tile.isHintAnimating = true;
      expect(tile.isHintAnimating, isTrue);

      tile.hintFrame = 'flag';
      expect(tile.hintFrame, 'flag');
    });

    test('two tiles are independent objects', () {
      final a = Tile()..isBomb = true;
      final b = Tile();
      expect(b.isBomb, isFalse,
          reason: 'Mutating one tile must not affect another');
    });

    test('adjacentBombs accepts all valid neighbour counts', () {
      for (var count = 0; count <= 8; count++) {
        final tile = Tile()..adjacentBombs = count;
        expect(tile.adjacentBombs, count);
      }
    });

    test('hintFrame accepts all expected frame names', () {
      const frames = ['flag', 'question', 'exclamation', 'safe'];
      for (final frame in frames) {
        final tile = Tile()..hintFrame = frame;
        expect(tile.hintFrame, frame);
      }
    });
  });
}
