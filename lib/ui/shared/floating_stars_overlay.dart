import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class FloatingStarsOverlay extends StatefulWidget {
  const FloatingStarsOverlay({
    super.key,
    this.starCount = 200,
    this.speed = 0.18, // 0..1-ish (higher = faster)
    this.minSize = 1,
    this.maxSize = 2.6,
    this.opacity = 0.7,
    this.minSparkleGapSeconds = 6.0, // ✅ rarer sparkles
    this.maxSparkleGapSeconds = 14.0,
    this.sparkleDurationSeconds = 0.14, // ✅ quick blink
    this.sparkleBoost = 0.55,
    this.sparkleGlowScale = 1.8,
  });

  final int starCount;
  final double speed;
  final double minSize;
  final double maxSize;
  final double opacity;

  // sparkle tuning
  final double minSparkleGapSeconds;
  final double maxSparkleGapSeconds;
  final double sparkleDurationSeconds;
  final double sparkleBoost;
  final double sparkleGlowScale;

  @override
  State<FloatingStarsOverlay> createState() => _FloatingStarsOverlayState();
}

class _Star {
  _Star({
    required this.x01,
    required this.y01,
    required this.size,
    required this.twinklePhase,
    required this.twinkleAmp,
    required this.twinkleSpeed,
    required this.nextSparkleAt,
  });

  final double x01; // 0..1
  double y01; // 0..1 (moves upward)
  final double size;

  final double twinklePhase;
  final double twinkleAmp;
  final double twinkleSpeed;

  // sparkle state
  bool isSparkling = false;
  double sparkleEndAt = 0.0;
  double nextSparkleAt; // seconds
}

class _FloatingStarsOverlayState extends State<FloatingStarsOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Star> _stars;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();

    double spread(double v) {
      // Push values away from center (0.5)
      final centered = v - 0.5;
      final amplified = centered * 1.4; // stronger spread
      return (amplified + 0.5).clamp(0.0, 1.0);
    }

    _stars = List.generate(widget.starCount, (_) {
      final depth = _rng.nextDouble(); // 0..1

      // initial sparkle time is randomized so they don't sync
      final initialSparkle = _rng.nextDouble() * widget.maxSparkleGapSeconds;

      return _Star(
        x01: spread(_rng.nextDouble()),
        y01: _rng.nextDouble(),
        size: widget.minSize + depth * (widget.maxSize - widget.minSize),
        twinklePhase: _rng.nextDouble() * math.pi * 2,
        twinkleAmp: 0.15 + depth * 0.45,
        twinkleSpeed: 0.5 + _rng.nextDouble() * 1.8,
        nextSparkleAt: initialSparkle,
      );
    });

    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 16000))
      ..addListener(_tick)
      ..repeat();
  }

  double _randRange(double a, double b) => a + _rng.nextDouble() * (b - a);

  void _tick() {
    final dt = 1 / 60; // “fake dt” good enough visually

    // We'll keep an "ever increasing time" in seconds for sparkle scheduling.
    // Using controller value alone loops; this accumulates via a local static.
    _timeSeconds += dt;

    for (final s in _stars) {
      // movement (parallax)
      final depthFactor = (s.size - widget.minSize) / (widget.maxSize - widget.minSize); // 0..1
      final dy = widget.speed * dt * (0.4 + depthFactor);

      s.y01 -= dy;
      if (s.y01 < -0.05) s.y01 = 1.05;

      // sparkle scheduling (rare + short)
      if (!s.isSparkling && _timeSeconds >= s.nextSparkleAt) {
        s.isSparkling = true;
        s.sparkleEndAt = _timeSeconds + widget.sparkleDurationSeconds;
      }

      if (s.isSparkling && _timeSeconds >= s.sparkleEndAt) {
        s.isSparkling = false;
        s.nextSparkleAt = _timeSeconds + _randRange(widget.minSparkleGapSeconds, widget.maxSparkleGapSeconds);
      }
    }

    setState(() {});
  }

  // local accumulated timeline (seconds)
  double _timeSeconds = 0.0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _StarsPainter(
          stars: _stars,
          baseOpacity: widget.opacity,
          t: _c.value,
          sparkleBoost: widget.sparkleBoost,
          sparkleGlowScale: widget.sparkleGlowScale,
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({
    required this.stars,
    required this.baseOpacity,
    required this.t,
    required this.sparkleBoost,
    required this.sparkleGlowScale,
  });

  final List<_Star> stars;
  final double baseOpacity;
  final double t; // 0..1 looping, used only for twinkle
  final double sparkleBoost;
  final double sparkleGlowScale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in stars) {
      final x = s.x01 * size.width;
      final y = s.y01 * size.height;

      // soft twinkle (0..1)
      final tw = (math.sin((t * math.pi * 2 * s.twinkleSpeed) + s.twinklePhase) * 0.5 + 0.5);

      // base opacity with per-star amplitude
      final base = (baseOpacity * (1 - s.twinkleAmp)) + (baseOpacity * s.twinkleAmp * tw);

      final boost = s.isSparkling ? sparkleBoost : 0.0;
      final finalOpacity = (base + boost).clamp(0.0, 1.0);

      paint.color = AppColors.goldColor.withOpacityCompat(finalOpacity);
      canvas.drawCircle(Offset(x, y), s.size, paint);

      // tiny extra glow when sparkling
      if (s.isSparkling) {
        paint.color = AppColors.goldColor.withOpacityCompat((finalOpacity * 0.40).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), s.size * sparkleGlowScale, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => true;
}
