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
    // final shouldAnimate = tile.isHintRevealed;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: tile.isRevealed ? 1.0 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            color: tile.isRevealed
                ? (tile.isBomb ? Colors.red.shade300 : Colors.grey.shade300)
                : Colors.blueAccent,
            border: Border.all(color: Colors.black),
          ),
          alignment: Alignment.center,
          child: tile.isRevealed
              ? tile.isBomb
                    ? const Icon(Icons.warning, color: Colors.black)
                    : (tile.adjacentBombs > 0
                          ? Text(
                              '${tile.adjacentBombs}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            )
                          : null)
              : (tile.isFlagged
                    ? const Icon(Icons.flag, size: 20, color: Colors.red)
                    : null),
        ),
      ),
    );
  }
}
