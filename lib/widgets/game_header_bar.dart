import 'package:flutter/material.dart';

class GameHeaderBar extends StatelessWidget {
  final int level;
  final int score;
  final VoidCallback onBackPressed;

  const GameHeaderBar({
    super.key,
    required this.level,
    required this.score,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0B1E3D)),
            onPressed: onBackPressed,
            tooltip: 'Back to Home',
          ),
          Text(
            'Level: $level',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'Acsioma',
              fontSize: 20,
              color: const Color(0xFF0B1E3D),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Score: $score',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'Acsioma',
              fontSize: 20,
              color: const Color(0xFF0B1E3D),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
