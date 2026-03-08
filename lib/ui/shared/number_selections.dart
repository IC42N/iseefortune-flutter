import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';

class NumberSelections extends StatelessWidget {
  const NumberSelections({super.key, required this.numbers, required this.size});
  final List<int> numbers;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [for (final n in numbers) NumberChip(n, size: size, intensity: 0.9)],
    );
  }
}
