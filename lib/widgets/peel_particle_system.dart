import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------------------
// Per-particle data — no widgets, no AnimationControllers.
// ---------------------------------------------------------------------------

class _Particle {
  final Offset startOffset;
  final Size tileSize;
  final double tossDir; // +1 = top-right corner peels, -1 = top-left
  final double angle; // flight direction in radians
  final double flyDistance; // pixels to travel after release
  final int startMs; // wall-clock ms at spawn time

  static const int durationMs = 600;

  const _Particle({
    required this.startOffset,
    required this.tileSize,
    required this.tossDir,
    required this.angle,
    required this.flyDistance,
    required this.startMs,
  });

  double progress(int nowMs) =>
      ((nowMs - startMs) / durationMs).clamp(0.0, 1.0);

  bool isDone(int nowMs) => nowMs - startMs >= durationMs;
}

// ---------------------------------------------------------------------------
// Singleton system — one OverlayEntry, one CustomPainter for every particle.
// ---------------------------------------------------------------------------

class PeelParticleSystem {
  PeelParticleSystem._();
  static final PeelParticleSystem instance = PeelParticleSystem._();

  // Match the old per-tile cap: never more than 24 flying at once.
  static const int _maxParticles = 24;

  final List<_Particle> _particles = [];
  final _rng = math.Random();
  OverlayEntry? _overlayEntry;
  bool _tickScheduled = false;
  int _currentMs = 0;

  /// Called by [TileWidget] when a tile is revealed.
  void addParticle(Offset startOffset, Size tileSize, BuildContext context) {
    if (_particles.length >= _maxParticles) return;
    _ensureOverlay(context);
    _currentMs = DateTime.now().millisecondsSinceEpoch;
    _particles.add(_Particle(
      startOffset: startOffset,
      tileSize: tileSize,
      tossDir: _rng.nextBool() ? 1.0 : -1.0,
      angle: _rng.nextDouble() * 2 * math.pi,
      flyDistance: 480 + _rng.nextDouble() * 260,
      startMs: _currentMs,
    ));
    _scheduleTick();
  }

  void _ensureOverlay(BuildContext context) {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _PeelPainter(
              particles: _particles,
              currentMs: _currentMs,
            ),
          ),
        ),
      ),
    );
    try {
      Overlay.of(context).insert(_overlayEntry!);
    } catch (_) {
      _overlayEntry = null;
    }
  }

  void _scheduleTick() {
    if (_tickScheduled) return;
    _tickScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    _tickScheduled = false;
    _currentMs = DateTime.now().millisecondsSinceEpoch;
    _particles.removeWhere((p) => p.isDone(_currentMs));

    try {
      _overlayEntry?.markNeedsBuild();
    } catch (_) {
      // Overlay was disposed (e.g. screen popped mid-animation) — clean up.
      _particles.clear();
      _overlayEntry = null;
      return;
    }

    if (_particles.isNotEmpty) {
      _scheduleTick();
    } else {
      try {
        _overlayEntry?.remove();
      } catch (_) {}
      _overlayEntry = null;
    }
  }
}

// ---------------------------------------------------------------------------
// Painter — all particles drawn on one canvas, zero extra compositing layers.
// ---------------------------------------------------------------------------

class _PeelPainter extends CustomPainter {
  final List<_Particle> particles;
  final int currentMs;

  _PeelPainter({required this.particles, required this.currentMs});

  static const double _peelEnd = 0.30;
  static const Color _tileColor = Color(0xFF1B2844);

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint();
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final p in particles) {
      final t = p.progress(currentMs);
      if (t <= 0.0 || t >= 1.0) continue;

      // ── Flight position ──────────────────────────────────────────────────
      final flightT = t <= _peelEnd
          ? 0.0
          : Curves.easeIn.transform((t - _peelEnd) / (1.0 - _peelEnd));
      final dx =
          p.startOffset.dx + math.cos(p.angle) * p.flyDistance * flightT;
      final dy =
          p.startOffset.dy + math.sin(p.angle) * p.flyDistance * flightT;

      // ── 3-D rotation (page-turn + toss) ─────────────────────────────────
      final double rotX;
      if (t <= _peelEnd) {
        rotX = -math.pi * Curves.easeIn.transform(t / _peelEnd);
      } else {
        rotX = -math.pi -
            math.pi *
                Curves.linear
                    .transform((t - _peelEnd) / (1.0 - _peelEnd));
      }
      final rotZ = p.tossDir * 0.40 * Curves.easeInOut.transform(t);

      // ── Pivot: Alignment(-1..1, -1..0) → pixel offset from tile top-left ─
      final pivotLerp = math.min(1.0, t / _peelEnd);
      final alignX = p.tossDir * (1.0 - pivotLerp);
      final alignY = -1.0 * (1.0 - pivotLerp);
      final pivotOffsetX = (alignX + 1.0) / 2.0 * p.tileSize.width;
      final pivotOffsetY = (alignY + 1.0) / 2.0 * p.tileSize.height;

      // ── Scale ─────────────────────────────────────────────────────────────
      final scale = t <= _peelEnd
          ? 1.0
          : 1.0 -
              0.55 *
                  Curves.easeIn
                      .transform((t - _peelEnd) / (1.0 - _peelEnd));

      // ── Opacity ───────────────────────────────────────────────────────────
      final opacity =
          (t < 0.70 ? 1.0 : 1.0 - ((t - 0.70) / 0.30)).clamp(0.0, 1.0);

      // ── Build matrix (perspective + rotations + scale) ────────────────────
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateX(rotX)
        ..rotateZ(rotZ)
        ..scale(scale);

      // ── Draw ──────────────────────────────────────────────────────────────
      canvas.save();
      // Move origin to the pivot point in screen space.
      canvas.translate(dx + pivotOffsetX, dy + pivotOffsetY);
      // Apply 3-D transform around that pivot.
      canvas.transform(matrix.storage);
      // Shift back so the tile top-left is at the canvas origin.
      canvas.translate(-pivotOffsetX, -pivotOffsetY);

      final rect =
          Rect.fromLTWH(0, 0, p.tileSize.width, p.tileSize.height);
      const radius = Radius.circular(4.0);

      fillPaint.color = _tileColor.withValues(alpha: opacity);
      borderPaint.color = Colors.black.withValues(alpha: opacity);

      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fillPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), borderPaint);

      canvas.restore();
    }
  }

  // Always repaint — the system only calls markNeedsBuild() when something
  // actually changed (once per frame while particles are alive).
  @override
  bool shouldRepaint(_PeelPainter _) => true;
}
