// lib/ui/shared/cosmic_orbit_border.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class CosmicOrbitBorder extends StatefulWidget {
  const CosmicOrbitBorder({
    super.key,
    required this.child,
    required this.radius,
    this.strokeWidth = 1.6,
    this.duration = const Duration(milliseconds: 2600),

    /// Optional accent hue you were using elsewhere.
    /// We keep it, but the "web gradient" palette will dominate.
    this.color = const Color(0xFFFFD54A),

    this.baseOpacity = 0.10,
    this.ringOpacity = 0.70,
    this.glowOpacity = 0.22,

    /// Glow blur strength (bigger = softer halo)
    this.glowSigma = 10,

    /// How much the border "breathes" (0..1)
    this.pulseAmount = 0.25,

    /// Pulse cycle duration multiplier relative to rotate duration
    this.pulseSpeed = 0.75,
  });

  final Widget child;

  final double radius;
  final double strokeWidth;
  final Duration duration;

  final Color color;

  /// Base static border opacity (very subtle)
  final double baseOpacity;

  /// Main gradient ring opacity
  final double ringOpacity;

  /// Glow around the ring
  final double glowOpacity;

  final double glowSigma;

  /// 0..1: strength of breathing effect
  final double pulseAmount;

  /// Multiplier for pulse rate vs rotation rate
  final double pulseSpeed;

  @override
  State<CosmicOrbitBorder> createState() => _CosmicOrbitBorderState();
}

class _CosmicOrbitBorderState extends State<CosmicOrbitBorder> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant CosmicOrbitBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _c.duration = widget.duration;
      if (_c.isAnimating) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          foregroundPainter: _OrbitPainter(
            t: _c.value,
            radius: widget.radius,
            strokeWidth: widget.strokeWidth,
            accent: widget.color,
            baseOpacity: widget.baseOpacity,
            ringOpacity: widget.ringOpacity,
            glowOpacity: widget.glowOpacity,
            glowSigma: widget.glowSigma,
            pulseAmount: widget.pulseAmount,
            pulseSpeed: widget.pulseSpeed,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.t,
    required this.radius,
    required this.strokeWidth,
    required this.accent,
    required this.baseOpacity,
    required this.ringOpacity,
    required this.glowOpacity,
    required this.glowSigma,
    required this.pulseAmount,
    required this.pulseSpeed,
  });

  final double t; // 0..1
  final double radius;
  final double strokeWidth;

  final Color accent;

  final double baseOpacity;
  final double ringOpacity;
  final double glowOpacity;

  final double glowSigma;
  final double pulseAmount;
  final double pulseSpeed;

  // Web-ish palette: #daf6ff, #abd1de, #53acc9, #67aec5, #daf6ff, #e4aafa
  static const _webStops = <double>[0.00, 0.18, 0.38, 0.58, 0.80, 1.00];
  static const _webColors = <Color>[
    Color(0xFFDAF6FF),
    Color(0xFFABD1DE),
    Color(0xFF53ACC9),
    Color(0xFF67AEC5),
    Color(0xFFDAF6FF),
    Color(0xFFE4AAFA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final inset = strokeWidth / 2;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(inset), Radius.circular(radius));

    // Base subtle border
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = accent.withOpacityCompat(baseOpacity);
    canvas.drawRRect(rrect, basePaint);

    // Rotate like CSS --angle (0..360deg)
    final angle = t * 2 * math.pi;

    // Pulse like CSS borderGlow (approx)
    final pulsePhase = (t * 2 * math.pi * pulseSpeed);
    final pulse = 1.0 + (math.sin(pulsePhase) * pulseAmount); // ~ [1-p, 1+p]

    // Build a sweep gradient ring.
    // We multiply alpha of the whole ring instead of "brightness/saturate" filters.
    final ringAlpha = (ringOpacity * pulse).clamp(0.0, 1.0);
    final glowAlpha = (glowOpacity * pulse).clamp(0.0, 1.0);

    final sweep = SweepGradient(
      transform: GradientRotation(angle),
      colors: _webColors.map((c) => c.withOpacityCompat(ringAlpha)).toList(growable: false),
      stops: _webStops,
    );

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = sweep.createShader(rect);

    // Glow: a soft blurred pass of the same gradient ring.
    if (glowAlpha > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 0.6
        ..shader = sweep.createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);

      // SaveLayer lets glow blend nicely over the blurred sheet.
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacityCompat(glowAlpha));
      canvas.drawRRect(rrect, glowPaint);
      canvas.restore();
    }

    // Crisp ring on top
    canvas.drawRRect(rrect, ringPaint);

    // Optional: tiny spec highlight runner (adds "alive" feel)
    // (If you want it OFF, delete this block.)
    final runner = SweepGradient(
      transform: GradientRotation(angle),
      colors: const [Colors.transparent, Colors.white, Colors.transparent],
      stops: const [0.48, 0.50, 0.52],
    );

    final runnerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = runner.createShader(rect)
      ..color = Colors.white.withOpacityCompat(0.22 * pulse);

    canvas.drawRRect(rrect, runnerPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) {
    return old.t != t ||
        old.radius != radius ||
        old.strokeWidth != strokeWidth ||
        old.accent != accent ||
        old.baseOpacity != baseOpacity ||
        old.ringOpacity != ringOpacity ||
        old.glowOpacity != glowOpacity ||
        old.glowSigma != glowSigma ||
        old.pulseAmount != pulseAmount ||
        old.pulseSpeed != pulseSpeed;
  }
}
