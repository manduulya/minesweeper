import 'package:flutter/material.dart';
import '../game.dart';
import 'tile_widget.dart';

class GameGridWidget extends StatelessWidget {
  final Game game;
  final Function(int, int) onTileTap;
  final Function(int, int) onTileLongPress;

  const GameGridWidget({
    super.key,
    required this.game,
    required this.onTileTap,
    required this.onTileLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Gap between tiles (smaller = closer)
    const double gap = 1.0;

    // ✅ Tile corner rounding (visual smoothness)
    const double tileRadius = 4.0;

    // ✅ Make tiles larger on tablets
    const double minTile = 18.0;
    const double maxTile = 68.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ Find active bounds (top/bottom/left/right of the shape)
        int minRow = game.rows, maxRow = -1, minCol = game.cols, maxCol = -1;

        for (int r = 0; r < game.rows; r++) {
          for (int c = 0; c < game.cols; c++) {
            if (game.board[r][c].isActive) {
              if (r < minRow) minRow = r;
              if (r > maxRow) maxRow = r;
              if (c < minCol) minCol = c;
              if (c > maxCol) maxCol = c;
            }
          }
        }

        // Fallback (should never happen)
        if (maxRow == -1) return const SizedBox.shrink();

        final activeRows = (maxRow - minRow + 1);
        final activeCols = (maxCol - minCol + 1);

        // ✅ Use BOTH width + height so iPad/tablets scale nicely
        final availableWidth = constraints.maxWidth;

        // If the parent gives infinite height, fall back to screen height fraction
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height * 0.60;

        final tileByWidth =
            (availableWidth - (gap * (activeCols - 1))) / activeCols;

        final tileByHeight =
            (availableHeight - (gap * (activeRows - 1))) / activeRows;

        var tileSize = tileByWidth < tileByHeight ? tileByWidth : tileByHeight;
        tileSize = tileSize.clamp(minTile, maxTile);

        final boardWidth = (activeCols * tileSize) + (gap * (activeCols - 1));
        final boardHeight = (activeRows * tileSize) + (gap * (activeRows - 1));

        return SizedBox(
          width: boardWidth,
          height: boardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int r = minRow; r <= maxRow; r++)
                for (int c = minCol; c <= maxCol; c++)
                  if (game.board[r][c].isActive)
                    Positioned(
                      left: (c - minCol) * (tileSize + gap),
                      top: (r - minRow) * (tileSize + gap),
                      width: tileSize,
                      height: tileSize,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(tileRadius),
                        child: TileWidget(
                          tile: game.board[r][c],
                          onTap: () => onTileTap(r, c),
                          onLongPress: () => onTileLongPress(r, c),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}
