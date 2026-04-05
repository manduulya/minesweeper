import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../tile.dart';

class TileWidget extends StatefulWidget {
  final Tile tile;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  // Relative grid position used to stagger peel animations (waterfall effect)
  final int gridRow;
  final int gridCol;

  const TileWidget({
    super.key,
    required this.tile,
    required this.onTap,
    required this.onLongPress,
    this.gridRow = 0,
    this.gridCol = 0,
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

  // Track previous revealed state ourselves — Tile is mutable so
  // oldWidget.tile and widget.tile point to the same object.
  bool _wasRevealed = false;
  bool _wasAnimating = false;
  bool _wasFlagged = false;

  @override
  void initState() {
    super.initState();
    _wasRevealed = widget.tile.isRevealed;
    _wasAnimating = widget.tile.shouldAnimate;
    _wasFlagged = widget.tile.isFlagged;

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
    if (widget.tile.shouldAnimate && !_wasAnimating) {
      _scaleController.forward();
      _pulseController.repeat(reverse: true);
    }

    // Stop animation when shouldAnimate becomes false
    if (!widget.tile.shouldAnimate && _wasAnimating) {
      _pulseController.stop();
      _scaleController.reset();
    }

    // Peel animation when any non-bomb tile is revealed
    if (widget.tile.isRevealed && !_wasRevealed && !widget.tile.isBomb) {
      _triggerPeelAnimation();
    }

    // Ripple when tile is freshly flagged
    if (widget.tile.isFlagged && !_wasFlagged) {
      _triggerFlagRipple();
    }

    _wasRevealed = widget.tile.isRevealed;
    _wasAnimating = widget.tile.shouldAnimate;
    _wasFlagged = widget.tile.isFlagged;
  }

  void _triggerFlagRipple() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final center = renderBox.localToGlobal(Offset.zero) +
          Offset(renderBox.size.width / 2, renderBox.size.height / 2);

      OverlayEntry? entry;
      entry = OverlayEntry(
        builder: (ctx) => _FlagRipple(
          center: center,
          onComplete: () => entry?.remove(),
        ),
      );
      Overlay.of(context).insert(entry);
    });
  }

  void _triggerPeelAnimation() {
    // Stagger by grid position: each row is 30 ms later, each col adds 8 ms.
    // This creates a top-to-bottom waterfall when many tiles reveal at once.
    final delayMs = widget.gridRow * 30 + widget.gridCol * 8;

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final globalOffset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      OverlayEntry? entry;
      entry = OverlayEntry(
        builder: (ctx) => _PeelParticle(
          startOffset: globalOffset,
          tileSize: size,
          onComplete: () => entry?.remove(),
        ),
      );
      Overlay.of(context).insert(entry);
    });
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
                            'assets/bombRevealed.webp',
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

// ---------------------------------------------------------------------------
// Flag ripple — expands outward from tile center in the Overlay so it is
// visible around the user's finger tip when long-pressing to flag.
// ---------------------------------------------------------------------------

class _FlagRipple extends StatefulWidget {
  final Offset center;
  final VoidCallback onComplete;

  const _FlagRipple({required this.center, required this.onComplete});

  @override
  State<_FlagRipple> createState() => _FlagRippleState();
}

class _FlagRippleState extends State<_FlagRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward().whenComplete(() {
        if (mounted) widget.onComplete();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_ctrl.value);
          final radius = 14.0 + t * 52.0; // 14 → 66 px
          final opacity = (1.0 - t).clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned(
                left: widget.center.dx - radius,
                top: widget.center.dy - radius,
                width: radius * 2,
                height: radius * 2,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade400,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Peel particle — rendered in the global Overlay so it escapes the grid clip
// ---------------------------------------------------------------------------

class _PeelParticle extends StatefulWidget {
  final Offset startOffset;
  final Size tileSize;
  final VoidCallback onComplete;

  const _PeelParticle({
    required this.startOffset,
    required this.tileSize,
    required this.onComplete,
  });

  @override
  State<_PeelParticle> createState() => _PeelParticleState();
}

class _PeelParticleState extends State<_PeelParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = math.Random();
  // +1 = top-right corner peels, -1 = top-left corner peels
  late final double _tossDir;
  // Random flight angle in radians (any direction)
  late final double _angle;
  // How far the tile travels after release (pixels)
  late final double _flyDistance;

  @override
  void initState() {
    super.initState();
    _tossDir = _rng.nextBool() ? 1.0 : -1.0;
    _angle = _rng.nextDouble() * 2 * math.pi;
    _flyDistance = 480 + _rng.nextDouble() * 260; // 480–740 px
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward().whenComplete(() {
        if (mounted) widget.onComplete();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double peelEnd = 0.30; // faster peel — off the surface sooner

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = _ctrl.value;

          // ── Position: stays in place during peel, then flies in _angle direction ──
          final flightT = t <= peelEnd
              ? 0.0
              : Curves.easeIn.transform((t - peelEnd) / (1.0 - peelEnd));
          final dx = widget.startOffset.dx +
              math.cos(_angle) * _flyDistance * flightT;
          final dy = widget.startOffset.dy +
              math.sin(_angle) * _flyDistance * flightT;

          // ── rotateX: page turn — top edge hinge, 180° during peel then coasts ──
          final double rotX;
          if (t <= peelEnd) {
            rotX = -math.pi * Curves.easeIn.transform(t / peelEnd);
          } else {
            rotX = -math.pi -
                math.pi *
                    1.0 *
                    Curves.linear.transform((t - peelEnd) / (1.0 - peelEnd));
          }

          // ── rotateZ: corner bias so one corner peels more than the other ──
          final rotZ = _tossDir * 0.40 * Curves.easeInOut.transform(t);

          // ── Pivot: top corner → center as it leaves the surface ──
          final pivotLerp = math.min(1.0, t / peelEnd);
          final pivotX = _tossDir * (1.0 - pivotLerp);
          final pivotY = -1.0 * (1.0 - pivotLerp);

          // ── Scale: shrinks after release ──
          final scale = t <= peelEnd
              ? 1.0
              : 1.0 - 0.55 * Curves.easeIn.transform(
                  (t - peelEnd) / (1.0 - peelEnd));

          // ── Opacity: fades in last 30% ──
          final opacity =
              t < 0.70 ? 1.0 : 1.0 - ((t - 0.70) / 0.30);

          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(rotX)
            ..rotateZ(rotZ)
            ..scale(scale);

          return Stack(
            children: [
              Positioned(
                left: dx,
                top: dy,
                width: widget.tileSize.width,
                height: widget.tileSize.height,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment(pivotX, pivotY),
                    transform: matrix,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B2844),
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      ),
    );
  }
}
