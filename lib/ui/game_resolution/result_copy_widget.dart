import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/game_resolution/game_resolution_model.dart';
import 'package:iseefortune_flutter/ui/game_resolution/result_copy.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class ResultCopyText extends StatelessWidget {
  const ResultCopyText({super.key, required this.copy, required this.outcome});

  final ResultCopy copy;
  final GameResolutionOutcome outcome;

  Color _toneColor() {
    switch (outcome) {
      case GameResolutionOutcome.win:
        return const Color(0xFF2FE36D);
      case GameResolutionOutcome.loss:
        return const Color(0xFFFF5A5A);
      case GameResolutionOutcome.rollover:
        return const Color(0xFFFFA24A);
      case GameResolutionOutcome.generic:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _toneColor();

    final headlineColor = (outcome == GameResolutionOutcome.generic)
        ? Colors.white.withOpacityCompat(0.92)
        : c.withOpacityCompat(0.90);

    // Subtle body: mostly neutral (web-like)
    final bodyColor = Colors.white.withOpacityCompat(0.72);
    final body = (copy.body ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          copy.headline,
          textAlign: TextAlign.center,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.10,
            color: headlineColor,
          ),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: bodyColor,
              height: 1.15,
            ),
          ),
        ],
      ],
    );
  }
}
