import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/stats_anim.dart';
import 'package:iseefortune_flutter/ui/shared/number_decoration.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class NumberProgressBar extends StatelessWidget {
  const NumberProgressBar({
    super.key,
    required this.number,
    required this.pct01, // 0..1
    this.height = 7,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.minVisibleWidth = 2.0, // helps avoid “1px jitter”
  });

  final int number;
  final double pct01;
  final double height;
  final Duration duration;
  final Curve curve;
  final double minVisibleWidth;

  @override
  Widget build(BuildContext context) {
    final v = pct01.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (context, c) {
          final trackW = c.maxWidth;
          var fillW = trackW * v;

          // Optional: keep tiny non-zero values visible and stable
          if (v > 0 && fillW < minVisibleWidth) fillW = minVisibleWidth;

          return SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Track
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacityCompat(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                // Fill (animated width)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: fillW,
                    height: height,
                    // If v==0, we still animate width to 0 cleanly; decoration can stay constant.
                    decoration: numberBarDecoration(
                      number,
                      isZero: v <= 0.0,
                      intensity: v <= 0.0 ? kBarZeroIntensity : kBarIntensity,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
