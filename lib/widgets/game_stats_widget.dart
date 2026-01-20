import 'package:flutter/material.dart';

class GameStatsWidget extends StatelessWidget {
  final int remainingFlags;
  final int winningStreak;
  final int hintCount;
  final bool showHintDecrease;
  final double scale1;
  final double scale2;
  final double scale3;

  const GameStatsWidget({
    super.key,
    required this.remainingFlags,
    required this.winningStreak,
    required this.hintCount,
    required this.showHintDecrease,
    required this.scale1,
    required this.scale2,
    required this.scale3,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            context: context,
            scale: scale1,
            icon: 'assets/bombRevealed.png',
            value: remainingFlags,
          ),
          _buildStatItem(
            context: context,
            scale: scale2,
            icon: 'assets/streakIcon.png',
            value: winningStreak,
          ),
          _buildHintStatItem(context),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required double scale,
    required String icon,
    required int value,
  }) {
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: scale == 1 ? 1 : 0,
        child: SizedBox(
          width: 60,
          child: Row(
            children: [
              Image.asset(icon, width: 24, height: 24),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: const Color(0xFF1B2844),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintStatItem(BuildContext context) {
    return AnimatedScale(
      scale: scale3,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: scale3 == 1 ? 1 : 0,
        child: SizedBox(
          width: 60,
          child: Row(
            children: [
              Image.asset('assets/hintButton.png', width: 24, height: 24),
              const SizedBox(width: 4),
              SizedBox(
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$hintCount',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: const Color(0xFF1B2844),
                      ),
                    ),
                    if (showHintDecrease)
                      Positioned(
                        top: -20,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: 0.0),
                          duration: const Duration(milliseconds: 600),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.scale(
                                scale: 1.2,
                                child: const Text(
                                  '-1',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
