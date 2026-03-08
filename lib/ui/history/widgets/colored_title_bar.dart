import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart'; // hsla()

class ColoredTitleBar extends StatelessWidget {
  const ColoredTitleBar({super.key, required this.title, required this.hueDeg});

  final String title;
  final int hueDeg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final glow = hsla(hueDeg.toDouble(), 0.85, 0.60, 0.45);
    final r = BorderRadius.circular(5);

    return SizedBox(
      width: double.infinity,
      height: 28,
      child: ClipRRect(
        borderRadius: r, // ✅ match outer
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.scale(
                  scaleX: 8.4, // spreads to the sides
                  scaleY: 0.9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, 0.2), // 50% x, ~60% y
                        radius: 1.55, // ✅ keep in sane Flutter range
                        colors: [glow, glow.withOpacityCompat(0.10), Colors.transparent],
                        stops: const [0.0, 0.55, 0.85],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Center(
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: Colors.white.withOpacityCompat(0.90),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
