import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/ui/shared/number_selections.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class AccordianTitle extends StatelessWidget {
  const AccordianTitle({super.key, required this.row});
  final ProfilePredictionRowVM row;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white.withOpacityCompat(0.92),
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );

    final subStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withOpacityCompat(0.55),
      height: 1.1,
      fontWeight: FontWeight.w600,
      fontSize: 10,
    );

    final amountStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withOpacityCompat(0.72),
      fontWeight: FontWeight.w400,
      fontSize: 12,
    );

    return Row(
      children: [
        // Middle: epoch/tier + time/tickets
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.titleLine, // "#925 • Tier 1"
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              //const SizedBox(height: 2),
              Text(row.core.timeLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Left: pick / range badge (uses core picks)
        NumberSelections(numbers: row.core.picks, size: 28),

        // shows "1 7" or "3" as chips, colored by your palette
        const SizedBox(width: 8),

        // Right: outcome + wager
        SizedBox(
          width: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.statusText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: row.statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              //const SizedBox(height: 2),
              Text(
                row.core.amountText, // "0.120 SOL" (wager)
                style: amountStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
