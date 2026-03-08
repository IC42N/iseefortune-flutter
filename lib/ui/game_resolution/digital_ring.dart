import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class DigitRingOrb extends StatefulWidget {
  const DigitRingOrb({super.key, required this.number, required this.ringIndex, required this.isFinal});

  final int number; // center number
  final int ringIndex; // highlighted digit on the ring (0..9)
  final bool isFinal;

  @override
  State<DigitRingOrb> createState() => _DigitRingOrbState();
}

class _DigitRingOrbState extends State<DigitRingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  late final Animation<double> _ringFade; // 1 -> 0 when final
  late final Animation<double> _centerFade; // 0 -> 1 when final
  late final Animation<double> _centerScale; // tiny -> full size (pop)

  @override
  void initState() {
    super.initState();

    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

    _ringFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.00, 0.55, curve: Curves.easeOut),
      ),
    );

    _centerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.30, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    // Slight overshoot feels “appearing”
    _centerScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.18, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.00).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
    ]).animate(_c);

    // If we mount already final (debug cases), jump to end.
    if (widget.isFinal) _c.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant DigitRingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When we flip into final, run the reveal sequence once.
    if (!oldWidget.isFinal && widget.isFinal) {
      _c.forward(from: 0.0);
    }

    // If you ever need to “reset” (not typical), this keeps it sane in debug:
    if (oldWidget.isFinal && !widget.isFinal) {
      _c.value = 0.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _clamp09(int n) => n.clamp(0, 9);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const cloudColor = Color(0xFFBFB47B);

    final centerColor = numberColor(_clamp09(widget.number), intensity: 1.0).withOpacityCompat(0.98);

    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background crystal ball SVG
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Opacity(
                  opacity: 0.52,
                  child: SvgPicture.asset(
                    'assets/svg/balls/crystal-ball-gold.svg',
                    width: 190,
                    height: 170,
                    colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),

          // Animated ring + center reveal
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final ringOpacity = widget.isFinal ? _ringFade.value : 1.0;
              final showCenter = widget.isFinal ? _centerFade.value : 0.0;
              final centerScale = widget.isFinal ? _centerScale.value : 0.18;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Orbiting digits ring (fade out on final)
                  Opacity(
                    opacity: ringOpacity,
                    child: CustomPaint(
                      size: const Size(120, 120),
                      painter: _DigitRingPainter(
                        activeIndex: widget.ringIndex,
                        isFinal: widget.isFinal,
                        ringOpacity: ringOpacity,
                        textStyle: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),

                  // Center orb shadow bloom (only when final / revealing)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: widget.isFinal ? 26 : 34,
                          spreadRadius: widget.isFinal ? 2 : 3,
                          color: (widget.isFinal ? centerColor : AppColors.goldColor).withOpacityCompat(
                            widget.isFinal ? 0.30 : 0.52,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center number (hidden while resolving; fades+scales in when final)
                  // Keep it in the tree so layout is stable.
                  Opacity(
                    opacity: showCenter,
                    child: Transform.scale(
                      scale: centerScale,
                      child: Text(
                        '${_clamp09(widget.number)}',
                        style: t.displayLarge!.copyWith(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: centerColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DigitRingPainter extends CustomPainter {
  _DigitRingPainter({
    required this.activeIndex,
    required this.isFinal,
    required this.ringOpacity,
    required this.textStyle,
  });

  final int activeIndex;
  final bool isFinal;
  final double ringOpacity; // lets us fade digits + glow smoothly
  final TextStyle? textStyle;

  int _clamp09(int n) => n.clamp(0, 9);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;
    final base = textStyle ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w800);

    final activeIdx = _clamp09(activeIndex);

    for (int i = 0; i < 10; i++) {
      final n = _clamp09(i);
      final angle = (-math.pi / 2) + (n * (2 * math.pi / 10));
      final pos = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);

      final bool active = n == activeIdx;

      // Base: tinted but subtle
      final baseCol = numberColor(n, intensity: 0.48).withOpacityCompat(0.15 * ringOpacity);

      // Active: brighter, higher intensity
      final activeCol = numberColor(n, intensity: isFinal ? 1.0 : 0.92).withOpacityCompat(0.95 * ringOpacity);

      final style = base.copyWith(
        color: active ? activeCol : baseCol,
        fontSize: active ? 18 : 14,
        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
      );

      final tp = TextPainter(
        text: TextSpan(text: '$n', style: style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final offset = pos - Offset(tp.width / 2, tp.height / 2);

      // Active glow (fades with ringOpacity too)
      if (active) {
        final glow = Paint()
          ..color = numberColor(
            n,
            intensity: isFinal ? 0.95 : 0.80,
          ).withOpacityCompat((isFinal ? 0.28 : 0.18) * ringOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        canvas.drawCircle(pos, 11, glow);
      }

      tp.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _DigitRingPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.isFinal != isFinal ||
        (oldDelegate.ringOpacity - ringOpacity).abs() > 0.001;
  }
}
