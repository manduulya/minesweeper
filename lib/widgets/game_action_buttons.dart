import 'package:flutter/material.dart';
import 'click_button_widget.dart';

class GameActionButtons extends StatefulWidget {
  final bool isHintMode;
  final bool canUseHint;
  final VoidCallback onHintPressed;
  final VoidCallback onRestartPressed;
  final Offset hintOffset;
  final Offset restartOffset;
  final bool compact;
  final double bottomPadding;
  final bool tryAgainMode;
  final bool watchAdForHintMode;
  final VoidCallback? onWatchAdForHintPressed;

  const GameActionButtons({
    super.key,
    required this.isHintMode,
    required this.canUseHint,
    required this.onHintPressed,
    required this.onRestartPressed,
    required this.hintOffset,
    required this.restartOffset,
    this.compact = false,
    this.bottomPadding = 0,
    this.tryAgainMode = false,
    this.watchAdForHintMode = false,
    this.onWatchAdForHintPressed,
  });

  @override
  State<GameActionButtons> createState() => _GameActionButtonsState();
}

class _GameActionButtonsState extends State<GameActionButtons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.tryAgainMode || widget.watchAdForHintMode) {
      _glowController.repeat(reverse: true);
    }
  }

  bool get _anyGlowActive => widget.tryAgainMode || widget.watchAdForHintMode;

  @override
  void didUpdateWidget(GameActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = oldWidget.tryAgainMode || oldWidget.watchAdForHintMode;
    if (_anyGlowActive && !wasActive) {
      _glowController.repeat(reverse: true);
    } else if (!_anyGlowActive && wasActive) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.compact ? 10.0 : 14.0;

    return Padding(
      padding: EdgeInsets.only(top: 12.0, bottom: 12.0 + widget.bottomPadding),
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
    final width = widget.compact ? 132.0 : 150.0;
    final iconSize = widget.compact ? 26.0 : 32.0;
    final fontSize = widget.compact ? 13.0 : 14.0;
    final vPad = widget.compact ? 7.0 : 8.0;
    final hPad = widget.compact ? 12.0 : 16.0;

    return AnimatedSlide(
      offset: widget.hintOffset,
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
        onPressed: widget.canUseHint
            ? () async {
                widget.onHintPressed();
                return Future.value();
              }
            : () async => Future.value(),
        child: Container(
          width: width,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: widget.isHintMode
                ? const Color(0xFF1B2844)
                : widget.canUseHint
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
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
              SizedBox(width: widget.compact ? 6 : 8),
              Flexible(
                child: Text(
                  widget.isHintMode ? 'Hint Mode' : 'Use Hint',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: widget.isHintMode
                        ? Colors.white
                        : widget.canUseHint
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
    final width = widget.compact ? 132.0 : 150.0;
    final iconSize = widget.compact ? 26.0 : 32.0;
    final fontSize = widget.compact ? 13.0 : 14.0;
    final vPad = widget.compact ? 7.0 : 8.0;
    final hPad = widget.compact ? 12.0 : 16.0;

    return AnimatedSlide(
      offset: widget.restartOffset,
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
          if (widget.tryAgainMode) {
            widget.onRestartPressed();
          } else {
            widget.onWatchAdForHintPressed?.call();
          }
          return Future.value();
        },
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            final glow = widget.tryAgainMode ? _glowAnimation.value : 0.0;
            return CustomPaint(
              painter: widget.tryAgainMode
                  ? _BorderGlowPainter(glow: glow, radius: 12)
                  : null,
              child: Container(
                width: width,
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.tryAgainMode
                  ? Image.asset(
                      'assets/restartButton.webp',
                      width: iconSize,
                      height: iconSize,
                    )
                  : Icon(
                      Icons.play_circle_outline,
                      size: iconSize,
                      color: Colors.white,
                    ),
              SizedBox(width: widget.compact ? 6 : 8),
              Text(
                widget.tryAgainMode ? 'Try Again' : 'Free Hint',
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

class _BorderGlowPainter extends CustomPainter {
  final double glow;
  final double radius;

  _BorderGlowPainter({required this.glow, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.orange.withValues(alpha: 0.6 + 0.4 * glow)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 6 * glow),
    );
  }

  @override
  bool shouldRepaint(_BorderGlowPainter old) => old.glow != glow;
}
