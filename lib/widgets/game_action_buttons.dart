import 'package:flutter/material.dart';
import 'click_button_widget.dart';

class GameActionButtons extends StatelessWidget {
  final bool isHintMode;
  final bool canUseHint;
  final VoidCallback onHintPressed;
  final VoidCallback onRestartPressed;
  final Offset hintOffset;
  final Offset restartOffset;

  /// ✅ NEW: when true (e.g. screenWidth < 400), buttons get smaller + fit better
  final bool compact;

  const GameActionButtons({
    super.key,
    required this.isHintMode,
    required this.canUseHint,
    required this.onHintPressed,
    required this.onRestartPressed,
    required this.hintOffset,
    required this.restartOffset,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 10.0 : 14.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: _buildHintButton()),
          SizedBox(width: gap),
          Flexible(child: _buildRestartButton()),
        ],
      ),
    );
  }

  Widget _buildHintButton() {
    final width = compact ? 132.0 : 150.0;
    final iconSize = compact ? 26.0 : 32.0;
    final fontSize = compact ? 13.0 : 14.0;
    final vPad = compact ? 7.0 : 8.0;
    final hPad = compact ? 12.0 : 16.0;

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
          width: width,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: isHintMode
                ? const Color(0xFF1B2844)
                : canUseHint
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            // border: Border.all(
            //   color: isHintMode
            //       ? const Color(0xFF1B2844)
            //       : canUseHint
            //       ? Colors.blue
            //       : Colors.grey,
            // ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/hintButton.webp',
                width: iconSize,
                height: iconSize,
              ),
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                child: Text(
                  isHintMode ? 'Hint Mode' : 'Use Hint',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: isHintMode
                        ? Colors.white
                        : canUseHint
                        ? Colors.blue
                        : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestartButton() {
    final width = compact ? 132.0 : 150.0;
    final iconSize = compact ? 26.0 : 32.0;
    final fontSize = compact ? 13.0 : 14.0;
    final vPad = compact ? 7.0 : 8.0;
    final hPad = compact ? 12.0 : 16.0;

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
          width: width,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            // border: Border.all(color: Colors.orange),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/restartButton.webp',
                width: iconSize,
                height: iconSize,
              ),
              SizedBox(width: compact ? 6 : 8),
              Text(
                'Restart',
                style: TextStyle(
                  fontSize: fontSize,
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
