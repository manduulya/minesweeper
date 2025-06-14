import 'package:flutter/material.dart';
import 'tile.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TileWidget({
    super.key,
    required this.tile,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.all(1),
        color: tile.isRevealed
            ? tile.isBomb
                  ? Colors.red
                  : Colors.grey
            : Colors.blue,
        child: Center(
          child: tile.isRevealed
              ? tile.isBomb
                    ? const Icon(Icons.warning, color: Colors.black)
                    : Text(
                        tile.adjacentBombs > 0 ? '${tile.adjacentBombs}' : '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
              : tile.isFlagged
              ? const Icon(Icons.flag, color: Colors.yellow)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
