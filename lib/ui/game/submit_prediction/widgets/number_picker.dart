// KEEP your _NumberPick exactly as-is below.
// (No change needed.)
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class NumberGrid extends StatelessWidget {
  const NumberGrid({super.key, required this.selected, required this.allowed, required this.onTap});

  final Set<int> selected;
  final Set<int> allowed;
  final void Function(int n) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(9, (i) {
        final n = i + 1;
        final isOn = selected.contains(n);
        final isAllowed = allowed.contains(n);

        return NumberPick(number: n, enabled: isAllowed, selected: isOn, onTap: () => onTap(n));
      }),
    );
  }
}

class NumberPick extends StatelessWidget {
  const NumberPick({
    super.key,
    required this.number,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final base = numberColor(number, intensity: 0.95, saturation: 0.95);

    final c1 = base.withOpacityCompat(((selected ? 1.0 : 0.85) * 0.45).clamp(0.0, 1.0));
    final c2 = numberColor(
      number,
      intensity: 0.55,
      saturation: 0.90,
    ).withOpacityCompat(((selected ? 1.0 : 0.85) * 0.22).clamp(0.0, 1.0));

    final hueBorder = numberColor(
      number,
      intensity: 0.85,
      saturation: 0.90,
    ).withOpacityCompat((selected ? 0.55 : 0.28));

    final baseDeco = BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        radius: 1.2,
        center: const Alignment(-0.35, -0.55),
        colors: [c1, c2],
        stops: const [0.0, 1.0],
      ),
      border: Border.all(color: hueBorder, width: 1.2),
      boxShadow: [
        BoxShadow(
          blurRadius: selected ? 18 : 14,
          offset: const Offset(0, 8),
          color: Colors.black.withOpacityCompat(selected ? 0.30 : 0.22),
        ),
        BoxShadow(
          blurRadius: 0,
          spreadRadius: -1,
          offset: const Offset(0, 1),
          color: Colors.white.withOpacityCompat(0.10),
        ),
      ],
    );

    final ringDeco = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFBFB47B).withOpacityCompat(0.90), width: 2.2),
      boxShadow: [
        BoxShadow(blurRadius: 18, spreadRadius: 1, color: const Color(0xFFBFB47B).withOpacityCompat(0.22)),
      ],
    );

    final disabledOverlay = BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.black.withOpacityCompat(0.32),
      border: Border.all(color: Colors.white.withOpacityCompat(0.06), width: 2),
    );

    final labelColor = enabled
        ? Colors.white.withOpacityCompat(selected ? 0.98 : 0.92)
        : Colors.white.withOpacityCompat(0.22);

    return Opacity(
      opacity: enabled ? 1.0 : 0.48,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 56,
          height: 56,
          decoration: baseDeco,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected) Positioned.fill(child: DecoratedBox(decoration: ringDeco)),
              if (!enabled) Positioned.fill(child: DecoratedBox(decoration: disabledOverlay)),
              Text(
                '$number',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: labelColor,
                  shadows: const [Shadow(blurRadius: 2, offset: Offset(0, 1), color: Color(0x59000000))],
                ),
              ),
              if (!enabled)
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Icon(Icons.lock_rounded, size: 14, color: Colors.white.withOpacityCompat(0.25)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
