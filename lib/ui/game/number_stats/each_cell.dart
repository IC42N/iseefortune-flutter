import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class NumberStatCell extends StatelessWidget {
  const NumberStatCell({
    super.key,
    required this.number,
    required this.child,
    this.minHeight = 110,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.showWatermark = true,
  });

  final int number;
  final Widget child;
  final double minHeight;
  final EdgeInsets padding;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    final base = numberColor(number, intensity: 0.9, saturation: 0.9);

    // Match CSS alphas
    final glow = base.withOpacityCompat(0.18);
    final border = base.withOpacityCompat(0.22);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Stack(
            children: [
              // Base glass + border
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withOpacityCompat(0.06),
                  border: Border.all(color: border, width: 1),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: RadialGradient(
                      radius: 2.6,
                      center: const Alignment(-0.6, -0.8), // ~20% 10%
                      colors: [glow, Colors.transparent],
                      stops: const [0.0, 0.60],
                    ),
                  ),
                ),
              ),

              // Inset 1px line (better approximation than boxShadow hack)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacityCompat(0.05), width: 1),
                    ),
                  ),
                ),
              ),

              // Watermark overlay
              if (showWatermark)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.15,
                      child: Center(
                        child: SvgPicture.asset('assets/svg/balls/ball-shine.svg', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),

              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
