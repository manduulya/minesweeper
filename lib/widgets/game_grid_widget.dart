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
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        double availableWidth = screenWidth - 24;
        double tileSize = (availableWidth - (2 * (game.cols - 1))) / game.cols;
        tileSize = tileSize.clamp(20.0, 40.0);

        double gridWidth = (tileSize * game.cols) + (2 * (game.cols - 1));
        double gridHeight = (tileSize * game.rows) + (2 * (game.rows - 1));

        return SizedBox(
          width: gridWidth,
          height: gridHeight,
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
              final tile = game.board[r][c];

              if (!tile.isActive) {
                return const SizedBox.shrink();
              }

              return SizedBox(
                width: tileSize,
                height: tileSize,
                child: TileWidget(
                  tile: tile,
                  onTap: () => onTileTap(r, c),
                  onLongPress: () => onTileLongPress(r, c),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
