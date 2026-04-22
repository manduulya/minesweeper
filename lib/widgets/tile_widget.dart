import 'dart:async';

import 'package:flutter/material.dart';
import '../tile.dart';
import 'peel_particle_system.dart';

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

  // Flag-ripple overlay entries — cleaned up in dispose() if the widget
  // leaves the tree while a ripple is still in flight.
  final List<OverlayEntry> _activeOverlays = [];
  // Stagger timer for the peel animation.
  Timer? _peelTimer;

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

    final prevFlagged = _wasFlagged;
    final prevRevealed = _wasRevealed;
    final prevAnimating = _wasAnimating;

    _wasRevealed = widget.tile.isRevealed;
    _wasAnimating = widget.tile.shouldAnimate;
    _wasFlagged = widget.tile.isFlagged;

    // Start animations when bomb is revealed with shouldAnimate
    if (widget.tile.shouldAnimate && !prevAnimating) {
      _scaleController.forward();
      _pulseController.repeat(reverse: true);
    }

    // Stop animation when shouldAnimate becomes false
    if (!widget.tile.shouldAnimate && prevAnimating) {
      _pulseController.stop();
      _scaleController.reset();
    }

    // Peel animation when any non-bomb tile is revealed
    if (widget.tile.isRevealed && !prevRevealed && !widget.tile.isBomb) {
      _triggerPeelAnimation();
    }

    // Ripple when tile is freshly flagged
    if (widget.tile.isFlagged && !prevFlagged) {
      _triggerFlagRipple();
    }

    // Force a rebuild when the tile's visual state changes. TileWidgets are
    // built inside LayoutBuilder's layout-phase callback, which can suppress
    // the normal post-didUpdateWidget rebuild in some Flutter versions.
    if (widget.tile.isFlagged != prevFlagged ||
        widget.tile.isRevealed != prevRevealed ||
        widget.tile.shouldAnimate != prevAnimating) {
      setState(() {});
    }
  }

  void _triggerFlagRipple() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final center = renderBox.localToGlobal(Offset.zero) +
          Offset(renderBox.size.width / 2, renderBox.size.height / 2);

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _FlagRipple(
          center: center,
          onComplete: () {
            _activeOverlays.remove(entry);
            try { entry.remove(); } catch (_) {}
          },
        ),
      );
      _activeOverlays.add(entry);
      Overlay.of(context).insert(entry);
    });
  }

  void _triggerPeelAnimation() {
    // Stagger by grid position: each row is 30 ms later, each col adds 8 ms.
    // This creates a top-to-bottom waterfall when many tiles reveal at once.
    final delayMs = widget.gridRow * 30 + widget.gridCol * 8;

    _peelTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      PeelParticleSystem.instance.addParticle(
        renderBox.localToGlobal(Offset.zero),
        renderBox.size,
        context,
      );
    });
  }

  @override
  void dispose() {
    _peelTimer?.cancel();
    for (final entry in _activeOverlays) {
      try { entry.remove(); } catch (_) {}
    }
    _activeOverlays.clear();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _getTileColor() {
    // Flagged tiles always look unrevealed — isFlagged takes priority.
    if (widget.tile.isFlagged) return const Color(0xFF1B2844);

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
    // Hint animation — uses AnimatedBuilder because it pulses via _pulseController.
    if (widget.tile.isHintAnimating && widget.tile.hintFrame != null) {
      IconData iconData;
      Color glowColor;

      switch (widget.tile.hintFrame) {
        case "flag":
          iconData = Icons.flag; // fallback only — replaced below
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
        default:
          return GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: const SizedBox.expand(),
          );
      }

      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final glowOpacity = 0.2 + 0.3 * _pulseController.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: glowOpacity),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                widget.tile.hintFrame == "flag"
                    ? Image.asset('assets/flag.webp', width: 20, height: 20)
                    : Icon(iconData, color: glowColor, size: 20),
              ],
            );
          },
        ),
      );
    }

    // Bomb explosion animation — uses AnimatedBuilder for per-frame color/scale.
    if (widget.tile.shouldAnimate && widget.tile.isBomb) {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              color: _getTileColor(),
              border: Border.all(color: Colors.black),
              boxShadow: [
                BoxShadow(
                  color: _colorAnimation.value?.withValues(alpha: 0.6) ??
                      Colors.transparent,
                  blurRadius: 8.0 * _pulseAnimation.value,
                  spreadRadius: 2.0 * _pulseAnimation.value,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Image.asset(
                'assets/bombRevealed.webp',
                width: 30,
                height: 30,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.dangerous,
                  size: 24,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Static tile — built directly so it always updates on setState, no
    // AnimatedBuilder indirection that could suppress a rebuild.
    final Widget? content;
    if (widget.tile.isFlagged) {
      content = Image.asset('assets/flag.webp', width: 20, height: 20);
    } else if (widget.tile.isRevealed) {
      if (widget.tile.isBomb) {
        content = Image.asset(
          'assets/bombRevealed.webp',
          width: 30,
          height: 30,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.dangerous,
            size: 24,
            color: Colors.black87,
          ),
        );
      } else if (widget.tile.adjacentBombs > 0) {
        content = Text(
          '${widget.tile.adjacentBombs}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        );
      } else {
        content = null;
      }
    } else {
      content = null;
    }

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: _getTileColor(),
          border: Border.all(color: Colors.black),
        ),
        alignment: Alignment.center,
        child: content,
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
    )..forward().whenComplete(widget.onComplete);
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

