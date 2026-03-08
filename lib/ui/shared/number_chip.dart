import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class NumberChip extends StatelessWidget {
  const NumberChip(
    this.number, {
    super.key,
    this.size = 30,
    this.intensity = 0.9,
    this.radius = 9, // matches web border-radius: 9px
  });

  final int number;
  final double size;
  final double intensity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gradStops = chipRadialStops(number, intensity);

    // Scale shadows with size (so it looks right for 24px, 30px, 40px, etc)
    final scale = (size / 30.0).clamp(0.8, 1.4);
    final dropBlur = 44.0 * scale;
    final dropY = 16.0 * scale;

    final glowBlur = 34.0 * scale;

    final r = BorderRadius.circular(radius);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ----------------------------------------------------------------
            // Base chip: radial gradient + border + big shadows/glow
            // ----------------------------------------------------------------
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: RadialGradient(
                  radius: 1.2, // 120% 120%
                  center: const Alignment(-0.4, -0.6), // ~30% 20%
                  colors: gradStops,
                  stops: const [0.0, 1.0],
                ),
                border: Border.all(color: chipBorder(number), width: 1),
                boxShadow: [
                  // drop shadow: 0 16px 44px rgba(0,0,0,.45)
                  BoxShadow(
                    color: Colors.black.withOpacityCompat(0.45),
                    blurRadius: dropBlur,
                    offset: Offset(0, dropY),
                  ),
                  // outer glow: 0 0 34px hsla(hue,95%,60%,0.25)
                  BoxShadow(color: chipGlow(number), blurRadius: glowBlur, offset: const Offset(0, 0)),
                ],
              ),
            ),

            // ----------------------------------------------------------------
            // Inset top highlight (simulate inset 0 1px 0 rgba(255,255,255,0.18))
            // ----------------------------------------------------------------
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacityCompat(0.18), Colors.white.withOpacityCompat(0.00)],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Inset bottom shading (simulate inset 0 -8px 18px rgba(0,0,0,0.25))
            // ----------------------------------------------------------------
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacityCompat(0.00), Colors.black.withOpacityCompat(0.25)],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Number text
            // ----------------------------------------------------------------
            Center(
              child: Text(
                number.toString(),
                style: t.bodyMedium?.copyWith(
                  fontSize: size * 0.52, // closer to web bold look
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: Colors.white.withOpacityCompat(0.92),
                  shadows: const [Shadow(blurRadius: 2, offset: Offset(0, 1), color: Color(0x59000000))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
