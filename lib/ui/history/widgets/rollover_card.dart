import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/history/widgets/glass_card.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class RolloverCard extends StatelessWidget {
  const RolloverCard({super.key, required this.palette, required this.reason});

  final RowHuePalette palette;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final text = reason.trim().isEmpty ? '—' : reason.trim();

    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Text('ROLLOVER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Divider(height: 1, color: Colors.white.withOpacityCompat(0.08)),

          // Reason block (wraps)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Text(
              text,
              softWrap: true,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.25, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
