import 'package:flutter/material.dart';
import 'package:mobile_experiment/click_button_widget.dart';
import '../game.dart';
import 'animated_start.dart';
import 'animated_counter.dart';
import 'show_level_overlay.dart';

class DialogUtils {
  /// Shows the win dialog with custom PNG background and slide animation
  static void showWinDialog({
    required BuildContext context,
    required Game game,
    required VoidCallback onNextLevel,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      transitionDuration: Duration(milliseconds: 800),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: Offset(0, -1), // Slide from top
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) =>
          Dialog.fullscreen(
            backgroundColor: Color(0xFF1B2844), // Custom color
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Win title
                  Text(
                    'Victory',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Acsioma',
                      fontSize: 65,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFffdd00),
                      // Adjust color to contrast with your background
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Animated stars
                  AnimatedStars(),
                  const SizedBox(height: 24),

                  // Level and score info
                  Container(
                    width: 400,
                    height: 600,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF294e71), Color(0xFF102a43)],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFFffa200),
                          width: 50,
                        ), // Thicker top border
                        left: BorderSide(color: Color(0xFFffa200), width: 25),
                        right: BorderSide(color: Color(0xFFffa200), width: 25),
                        bottom: BorderSide(color: Color(0xFFffa200), width: 25),
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        Text(
                          'Level ${game.level}\nComplete!',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontFamily: 'Topaz',
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Color(0xFF78a7d1),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0, 4),
                                blurRadius: 8,
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedCounter(
                                value: game.finalScore,
                                prefix: 'Score: ',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontFamily: 'Acsioma',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF102a43),
                                    ),
                              ),
                              AnimatedCounter(
                                value: game.bombCount,
                                prefix: 'Mines: ',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontFamily: 'Acsioma',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF102a43),
                                    ),
                              ),
                              AnimatedCounter(
                                value: game.hintCount,
                                prefix: 'Hints: ',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontFamily: 'Acsioma',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF102a43),
                                    ),
                              ),
                              if (game.bonus > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: AnimatedCounter(
                                    value: game.bonus,
                                    prefix: 'Bonus: ',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontFamily: 'Acsioma',
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF102a43),
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: ClickButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onNextLevel();
                              showLevelOverlay(context, game.level + 1);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 16,
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                            child: Text(
                              'Next Level',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  /// Shows the game over dialogwaeg
  static void showGameOverDialog({
    required BuildContext context,
    required Game game,
    required VoidCallback onRetry,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF1B2844),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFffa200), width: 25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Game Over \nYou Hit a Mine!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Topaz',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),
                ClickButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRetry();
                    showLevelOverlay(context, game.level);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showGameStartDialog({
    required BuildContext context,
    required Game game,
    required VoidCallback onStart,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF1B2844),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFffa200), width: 25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Level ${game.level}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Topaz',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFF78a7d1),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, 4),
                        blurRadius: 8,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCounter(
                        value: game.finalScore,
                        prefix: 'Score: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'Acsioma',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF102a43),
                        ),
                      ),
                      AnimatedCounter(
                        value: game.winningStreak,
                        prefix: 'Streak: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'Acsioma',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF102a43),
                        ),
                      ),
                      AnimatedCounter(
                        value: game.hintCount,
                        prefix: 'Hints: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'Acsioma',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF102a43),
                        ),
                      ),
                      ClickButton(
                        onPressed: () {
                          onStart();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
