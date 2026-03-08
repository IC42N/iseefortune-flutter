// lib/ui/history/widgets/game_box.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class GameBox extends StatelessWidget {
  const GameBox({super.key, required this.hueDeg, required this.child});

  final int hueDeg;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Stronger / more visible than before
    final glow = hsla(hueDeg.toDouble(), 0.85, 0.55, 0.32);
    final glowSoft = hsla(hueDeg.toDouble(), 0.85, 0.55, 0.14);

    final borderHue = hsla(hueDeg.toDouble(), 0.90, 0.70, 0.22);
    final borderHueSoft = hsla(hueDeg.toDouble(), 0.90, 0.70, 0.10);

    return Container(
      width: double.infinity,
      height: double.infinity, // IMPORTANT: make the box fill the available height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.black.withOpacityCompat(0.26), // keep this low so glow is visible
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacityCompat(0.45), blurRadius: 34, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Glow layer (this is your ::after)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -1.0), // ~30% 0% like CSS
                      radius: 1.2,
                      colors: [glow, glowSoft, Colors.transparent],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Inner depth layer (dark glass)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(color: Colors.black.withOpacityCompat(0.16))),
              ),
            ),

            // Slight blur look (optional, helps feel like CSS filter blur)
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),

            // Border + inner inset stroke
            // Border + inner inset stroke (hue tinted)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderHue, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1), // inner inset stroke
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: borderHueSoft, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content on top
            child,
          ],
        ),
      ),
    );
  }
}
