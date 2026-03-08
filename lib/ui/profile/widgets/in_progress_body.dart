import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class InProgressBody extends StatelessWidget {
  const InProgressBody({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacityCompat(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacityCompat(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.goldColor.withOpacityCompat(0.85)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Game still in progress.\nYou can view results here after the game completes.',
                  style: t.bodySmall?.copyWith(
                    color: Colors.white.withOpacityCompat(0.78),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
