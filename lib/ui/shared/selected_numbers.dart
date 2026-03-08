import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';

class SelectedNumbers extends StatelessWidget {
  const SelectedNumbers({
    super.key,
    required this.numbers,
    this.size = 22,
    this.opacity = 0.65,
    this.align = Alignment.centerRight,
    this.spacing = 6,
    this.runSpacing = 6,
  });

  final List<int> numbers;
  final double size;
  final double opacity;
  final Alignment align;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (numbers.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: align,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final n in numbers)
            Opacity(
              opacity: opacity,
              child: NumberChip(n, size: size, intensity: 0.85),
            ),
        ],
      ),
    );
  }
}
