import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SubmitPredictionState>();

    final (title, subtitle) = _copyFor(step: step, s: s);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white.withOpacityCompat(0.85),
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 12,
            color: Colors.white.withOpacityCompat(0.60),
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  (String, String) _copyFor({required int step, required SubmitPredictionState s}) {
    // Step 0 depends on entry
    if (step == 0) {
      if (s.isManageEntry) {
        return (
          'Your prediction',
          'Increase your conviction amount or if you have a change ticket, you can change your prediction here.',
        );
      }

      // 0b) Change-number selection screen
      if (s.action == PredictionAction.changeNumber) {
        final c = s.baseSelectionCount;
        final countLabel = (c <= 0) ? 'the same count' : '$c';
        return (
          'Make your selection',
          'Select your new prediction${c == 1 ? '' : 's'}. You must select the same count ($countLabel) as your original prediction.',
        );
      }

      // 0c) Place prediction selection screen
      return (
        'Make your selection',
        'Select one or more numbers. Helpers let you quickly select multiple. Rollover number is locked.',
      );
    }

    // Step 1 depends on action
    if (s.action == PredictionAction.increase) {
      return (
        'Increase Position',
        'Increasing your position will increase your share when you win. Amount is applied per selected number.',
      );
    }

    if (s.action == PredictionAction.changeNumber) {
      return ('Review & confirm', 'Confirm your new selection before submitting.');
    }

    // place
    return (
      'How sure are you?',
      'Set your conviction and review before submitting. Amount is applied per selected number.',
    );
  }
}
