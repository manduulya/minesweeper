import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback? onSplashComplete;

  const AnimatedSplashScreen({super.key, this.onSplashComplete});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _floatController;
  late final Ticker _sparkTicker;

  final _rand = Random();

  // Sparks state
  final List<_Spark> _sparks = [];
  Duration _lastSparkTime = Duration.zero;

  // Fuse location on the logo (normalized 0..1)
  final Offset _fuseAnchor = const Offset(0.42, 0.14);

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _sparkTicker = createTicker(_onSparkTick)..start();

    Timer(const Duration(seconds: 3), () {
      widget.onSplashComplete?.call();
    });
  }

  void _onSparkTick(Duration elapsed) {
    // Emit sparks ~ every 70–130ms
    if ((elapsed - _lastSparkTime).inMilliseconds > (70 + _rand.nextInt(60))) {
      _lastSparkTime = elapsed;
      _emitSparkBurst();
    }

    final dt = 1 / 60.0;
    for (int i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.vy += 60 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;

      if (s.life <= 0) _sparks.removeAt(i);
    }

    if (mounted) setState(() {});
  }

  void _emitSparkBurst() {
    final count = 1 + _rand.nextInt(3);

    for (int i = 0; i < count; i++) {
      final angle = (-pi / 2) + (_rand.nextDouble() * 0.9 - 0.45);
      final speed = 120 + _rand.nextDouble() * 220;

      _sparks.add(
        _Spark(
          x: 0,
          y: 0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: 2 + _rand.nextDouble() * 3,
          life: 0.35 + _rand.nextDouble() * 0.35,
          alpha: 0.9,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sparkTicker.dispose();
    _glowController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background1.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_floatController, _glowController]),
              builder: (context, _) {
                final floatY = ui.lerpDouble(-6, 6, _floatController.value)!;
                final glowStrength = ui.lerpDouble(
                  0.35,
                  0.95,
                  _glowController.value,
                )!;

                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      children: [
                        // Base bomb image (untinted)
                        Positioned.fill(
                          child: Image.asset(
                            'assets/appicon.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Localized fuse glow (does NOT tint the whole logo)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FuseGlowPainter(
                              fuseAnchor: _fuseAnchor,
                              strength: glowStrength,
                            ),
                          ),
                        ),

                        // Sparks
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SparksPainter(
                              sparks: _sparks,
                              fuseAnchor: _fuseAnchor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Spark {
  double x, y;
  double vx, vy;
  double size;
  double life;
  double alpha;

  _Spark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.alpha,
  });
}

class _SparksPainter extends CustomPainter {
  final List<_Spark> sparks;
  final Offset fuseAnchor;

  _SparksPainter({required this.sparks, required this.fuseAnchor});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(
      size.width * fuseAnchor.dx,
      size.height * fuseAnchor.dy,
    );

    for (final s in sparks) {
      final p = origin + Offset(s.x, s.y);

      final paint = Paint()
        ..color = Colors.orange.withValues(
          alpha: (s.life.clamp(0, 1) * s.alpha),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(p, s.size, paint);

      final core = Paint()
        ..color = Colors.yellow.withValues(alpha: (s.life.clamp(0, 1) * 0.9));
      canvas.drawCircle(p, s.size * 0.45, core);
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter oldDelegate) => true;
}

class _FuseGlowPainter extends CustomPainter {
  final Offset fuseAnchor;
  final double strength;

  _FuseGlowPainter({required this.fuseAnchor, required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * fuseAnchor.dx,
      size.height * fuseAnchor.dy,
    );

    // Bigger radius = softer glow around fuse only
    final radius = size.shortestSide * 0.22;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          const Color(0xFFFFF2B0).withValues(alpha: 0.55 * strength),
          const Color(0xFFFF7A18).withValues(alpha: 0.35 * strength),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      )
      ..blendMode = BlendMode.screen;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _FuseGlowPainter oldDelegate) =>
      oldDelegate.strength != strength || oldDelegate.fuseAnchor != fuseAnchor;
}
