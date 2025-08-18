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
      // child: AnimatedOpacity(
      // duration: const Duration(milliseconds: 400),
      // opacity: tile.isRevealed ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: tile.isRevealed
              ? (tile.isBomb ? Colors.red.shade300 : Colors.grey.shade300)
              : const Color(0xFF1B2844),
          border: Border.all(color: Colors.black),
        ),
        alignment: Alignment.center,
        child: tile.isRevealed
            ? tile.isBomb
                  ? Image.asset(
                      'assets/bombRevealed.png',
                      width: 30,
                      height: 30,
                    )
                  : (tile.adjacentBombs > 0
                        ? Text(
                            '${tile.adjacentBombs}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
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
      // ),
    );
  }
}
