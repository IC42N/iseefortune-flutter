import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/gradient_ring.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.handle,
    required this.subtitle,
    required this.accent,
    required this.onClose,
  });

  final String handle;
  final String subtitle;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const innerSize = 180.0; // your circle
    const ring = 3.6;
    const pad = 6.0; // breathing room for stroke + glow
    final outer = innerSize + (pad * 2);
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: outer,
        height: outer,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // important
          children: [
            // shadow behind everything (give it a real size)
            SizedBox(
              width: innerSize,
              height: innerSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacityCompat(0.85),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: accent.withOpacityCompat(0.18),
                      blurRadius: 26,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),

            // inner fill
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(color: AppColors.darkBlue, shape: BoxShape.circle),
            ),

            // ring gets space
            GradientRing(size: innerSize, strokeWidth: ring),

            // content
            ClipOval(
              child: Container(
                width: innerSize - (ring * 2),
                height: innerSize - (ring * 2),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      handle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 19,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      subtitle.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        color: AppColors.goldColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
