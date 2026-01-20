import 'package:flutter/material.dart';
import 'click_button_widget.dart';

class GameActionButtons extends StatelessWidget {
  final bool isHintMode;
  final bool canUseHint;
  final VoidCallback onHintPressed;
  final VoidCallback onRestartPressed;
  final Offset hintOffset;
  final Offset restartOffset;

  const GameActionButtons({
    super.key,
    required this.isHintMode,
    required this.canUseHint,
    required this.onHintPressed,
    required this.onRestartPressed,
    required this.hintOffset,
    required this.restartOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [_buildHintButton(), _buildRestartButton()],
      ),
    );
  }

  Widget _buildHintButton() {
    return AnimatedSlide(
      offset: hintOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: ClickButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: canUseHint
            ? () async {
                onHintPressed();
                return Future.value();
              }
            : () async => Future.value(),
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isHintMode
                ? const Color(0xFF1B2844)
                : canUseHint
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHintMode
                  ? const Color(0xFF1B2844)
                  : canUseHint
                  ? Colors.blue
                  : Colors.grey,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/hintButton.png', width: 32, height: 32),
              const SizedBox(width: 8),
              Text(
                isHintMode ? 'Hint Mode' : 'Use Hint',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isHintMode
                      ? Colors.white
                      : canUseHint
                      ? Colors.blue
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestartButton() {
    return AnimatedSlide(
      offset: restartOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: ClickButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          onRestartPressed();
          return Future.value();
        },
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/restartButton.png', width: 32, height: 32),
              const SizedBox(width: 8),
              const Text(
                'Restart',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
