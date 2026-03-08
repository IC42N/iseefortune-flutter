import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

Widget selectionNumbers(BuildContext context, SubmitPredictionState s) {
  if (s.numbers.isEmpty) return const SizedBox.shrink();
  final nums = s.sortedNums;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Selected',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 12,
          color: Colors.white.withOpacityCompat(0.65),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [for (final n in nums) NumberChip(n, size: 30, intensity: 0.9)],
      ),
    ],
  );
}
