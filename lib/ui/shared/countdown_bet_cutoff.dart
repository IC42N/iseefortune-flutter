import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iseefortune_flutter/providers/bet_cutoff_provider.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

class BetCutoffText extends StatelessWidget {
  const BetCutoffText({super.key, this.compact = false, this.style});

  final bool compact;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final comma = NumberFormat.decimalPattern();

    return Selector<BetCutoffProvider, _VM>(
      selector: (_, bet) {
        final slotsLeft = bet.stats?.slotsUntilCutoff ?? 0;
        return _VM(isSynced: bet.isSynced, bettingOpen: bet.bettingOpen, slotsLeft: slotsLeft);
      },
      builder: (context, vm, _) {
        final t = Theme.of(context).textTheme;
        final base = style ?? t.labelMedium;

        if (!vm.isSynced) {
          return Text(compact ? '…' : 'Bet cutoff: …', style: base);
        }

        if (!vm.bettingOpen) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 12, color: AppColors.red),
              const SizedBox(width: 4),
              Text(
                compact ? 'CLOSED' : 'Bet cutoff: CLOSED',
                style: base?.copyWith(fontWeight: FontWeight.w800, color: AppColors.red),
              ),
            ],
          );
        }

        final label = compact ? 'Cutoff in' : 'Bet cutoff:';
        final slotsText = comma.format(vm.slotsLeft);

        final textStyle = base?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.goldColor.withOpacityCompat(0.82),
          letterSpacing: compact ? 1.1 : 0.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

        final number = SizedBox(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(slotsText, style: textStyle),
          ),
        );

        return SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(label.toUpperCase(), style: textStyle),
              const SizedBox(width: 3),
              number,
              if (!compact) Text(' slots', style: textStyle),
            ],
          ),
        );
      },
    );
  }
}

class _VM {
  const _VM({required this.isSynced, required this.bettingOpen, required this.slotsLeft});
  final bool isSynced;
  final bool bettingOpen;
  final int slotsLeft;
}
