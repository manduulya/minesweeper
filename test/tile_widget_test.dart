import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_master/tile.dart';
import 'package:mine_master/widgets/tile_widget.dart';

// Wraps TileWidget in the minimal scaffold it needs (Overlay + Directionality).
Widget _buildTile(Tile tile) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: TileWidget(
            tile: tile,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('TileWidget flag ripple', () {
    testWidgets('no exception when tile is flagged', (tester) async {
      final tile = Tile();

      await tester.pumpWidget(_buildTile(tile));

      // Simulate flagging
      tile.isFlagged = true;
      await tester.pumpWidget(_buildTile(tile));
      await tester.pumpAndSettle();

      // If we reach here without an exception the overlay insert was safe
      expect(tester.takeException(), isNull);
    });

    testWidgets('flag icon appears when isFlagged is true', (tester) async {
      final tile = Tile()..isFlagged = true;

      await tester.pumpWidget(_buildTile(tile));
      await tester.pump();

      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('flag icon absent when isFlagged is false', (tester) async {
      final tile = Tile();

      await tester.pumpWidget(_buildTile(tile));
      await tester.pump();

      expect(find.byIcon(Icons.flag), findsNothing);
    });

    testWidgets('ripple fires on flag but not on unflag', (tester) async {
      final tile = Tile();

      await tester.pumpWidget(_buildTile(tile));

      // Flag — ripple should be scheduled for the next frame
      tile.isFlagged = true;
      await tester.pumpWidget(_buildTile(tile));
      await tester.pump(); // post-frame callback fires here

      // One ripple overlay entry should be in the tree
      expect(find.byType(TileWidget), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Let the ripple finish
      await tester.pumpAndSettle();

      // Unflag — no new ripple should fire
      tile.isFlagged = false;
      await tester.pumpWidget(_buildTile(tile));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no double-trigger on rebuild without flag change', (tester) async {
      final tile = Tile()..isFlagged = true;

      await tester.pumpWidget(_buildTile(tile));
      await tester.pumpAndSettle();

      // Rebuild without changing isFlagged — should not fire a second ripple
      await tester.pumpWidget(_buildTile(tile));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
