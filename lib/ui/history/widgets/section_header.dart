import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/dark_button.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.epoch,
    required this.tier,
    required this.rightButtonText,
    required this.onRightTap,
    required this.color,
  });

  final String title;
  final String epoch;
  final String tier;
  final String rightButtonText;
  final VoidCallback onRightTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: 13,
      color: Colors.white70.withOpacityCompat(0.6),
      letterSpacing: 1.1,
      fontWeight: FontWeight.w600,
    );

    final epochStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 17,
      color: color,
      fontWeight: FontWeight.w700,
    );

    final subStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 17,
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: EdgeInsetsGeometry.fromLTRB(4, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: titleStyle),
                Row(
                  children: [
                    Text(epoch, style: epochStyle),
                    Text('  •  ', style: subStyle),
                    Text(tier, style: subStyle),
                  ],
                ),
              ],
            ),
          ),
          darkButton(label: rightButtonText, onTap: onRightTap),
        ],
      ),
    );
  }
}
