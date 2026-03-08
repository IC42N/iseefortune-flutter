import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class WinningNumberCard extends StatelessWidget {
  const WinningNumberCard({super.key, required this.winningNumber, required this.palette});

  final int winningNumber;
  final RowHuePalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _WinBubble(label: 'Winning number', value: '$winningNumber', theme: theme);
  }
}

class _WinBubble extends StatelessWidget {
  const _WinBubble({required this.label, required this.value, required this.theme});

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
        color: Colors.white.withOpacityCompat(0.05),
        boxShadow: [
          // 0 10px 26px rgba(0,0,0,0.35)
          const BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 26, offset: Offset(0, 10)),
          // 0 0 26px rgba(255,255,255,0.06)
          BoxShadow(color: Colors.white.withOpacityCompat(0.06), blurRadius: 26, offset: Offset.zero),
        ],
      ),
      child: Stack(
        children: [
          // Radial highlight:
          // radial-gradient(120px 120px at 30% 30%, rgba(255,255,255,0.16), transparent 60%)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Align(
                  alignment: const Alignment(-0.4, -0.4), // ~30% 30%
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [Color.fromRGBO(255, 255, 255, 0.16), Colors.transparent],
                        stops: [0.0, 0.60],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content (label + big number)
          // Content (label + big number)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: Colors.white.withOpacityCompat(0.70),
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
