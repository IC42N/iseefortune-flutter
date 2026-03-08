import 'dart:math' as math;
import 'package:flutter/material.dart';

class GradientRing extends StatelessWidget {
  const GradientRing({
    super.key,
    required this.size,
    required this.strokeWidth,
    this.rotateT,
    this.innerPad = 0.0,
  });

  final double size;
  final double strokeWidth;
  final double? rotateT;
  final double innerPad;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GradientRingPainter(strokeWidth: strokeWidth, t: rotateT ?? 0.0, innerPad: innerPad),
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  _GradientRingPainter({required this.strokeWidth, required this.t, required this.innerPad});

  final double strokeWidth;
  final double t;
  final double innerPad;

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

    final rect = Offset.zero & size;

    // ✅ draw slightly inset so any parent clipping won't chop the ring
    final inset = (strokeWidth / 2) + innerPad;

    final r = (size.shortestSide / 2) - inset;
    if (r <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    final angle = t * 2 * math.pi;

    final shader = SweepGradient(
      transform: GradientRotation(angle),
      colors: _webColors,
      stops: _webStops,
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..shader = shader;

    canvas.drawCircle(center, r, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter old) {
    return old.strokeWidth != strokeWidth || old.t != t || old.innerPad != innerPad;
  }
}
