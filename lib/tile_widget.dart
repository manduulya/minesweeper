import 'package:flutter/material.dart';
import 'tile.dart';

class TileWidget extends StatefulWidget {
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
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for color fading
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale animation for reveal effect
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.red.shade400,
      end: Colors.yellow.shade400,
    ).animate(_pulseAnimation);
  }

  @override
  void didUpdateWidget(TileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start animations when bomb is revealed with shouldAnimate
    if (widget.tile.shouldAnimate && !oldWidget.tile.shouldAnimate) {
      _scaleController.forward();
      _pulseController.repeat(reverse: true);
    }

    // Stop animation when shouldAnimate becomes false
    if (!widget.tile.shouldAnimate && oldWidget.tile.shouldAnimate) {
      _pulseController.stop();
      _scaleController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _getTileColor() {
    if (widget.tile.shouldAnimate &&
        widget.tile.isBomb &&
        widget.tile.isRevealed) {
      return _colorAnimation.value ?? Colors.red.shade400;
    }

    if (widget.tile.isRevealed) {
      if (widget.tile.isBomb) {
        return Colors.red.shade300;
      } else {
        return Colors.grey.shade300;
      }
    } else {
      return const Color(0xFF1B2844);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          if (widget.tile.isHintAnimating && widget.tile.hintFrame != null) {
            IconData iconData;
            Color glowColor;

            switch (widget.tile.hintFrame) {
              case "flag":
                iconData = Icons.flag;
                glowColor = const Color.fromARGB(255, 78, 18, 14);
                break;
              case "question":
                iconData = Icons.help_outline;
                glowColor = const Color.fromARGB(255, 12, 19, 80);
                break;
              case "exclamation":
                iconData = Icons.priority_high;
                glowColor = Colors.red;
                break;
              case "safe":
                return const SizedBox();
              default:
                return const SizedBox();
            }

            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                double glowOpacity = 0.2 + 0.3 * _pulseController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow behind the icon
                    if (widget.tile.hintFrame != "safe")
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withOpacity(glowOpacity),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    Icon(iconData, color: glowColor, size: 20),
                  ],
                );
              },
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: _getTileColor(),
              border: Border.all(color: Colors.black),
              boxShadow: widget.tile.shouldAnimate && widget.tile.isBomb
                  ? [
                      BoxShadow(
                        color:
                            _colorAnimation.value?.withOpacity(0.6) ??
                            Colors.transparent,
                        blurRadius: 8.0 * _pulseAnimation.value,
                        spreadRadius: 2.0 * _pulseAnimation.value,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.tile.isRevealed
                ? widget.tile.isBomb
                      ? Transform.scale(
                          scale: widget.tile.shouldAnimate
                              ? _scaleAnimation.value
                              : 1.0,
                          child: Image.asset(
                            'assets/bombRevealed.png',
                            width: 30,
                            height: 30,
                          ),
                        )
                      : (widget.tile.adjacentBombs > 0
                            ? Text(
                                '${widget.tile.adjacentBombs}',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.black,
                                    ),
                              )
                            : null)
                : (widget.tile.isFlagged
                      ? const Icon(Icons.flag, size: 20, color: Colors.red)
                      : null),
          );
        },
      ),
    );
  }
}
