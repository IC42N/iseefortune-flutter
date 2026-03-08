import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';
import 'package:iseefortune_flutter/ui/shared/card_shell.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class TopRow extends StatelessWidget {
  const TopRow({super.key, required this.vm});
  final LiveFeedVM vm;

  @override
  Widget build(BuildContext context) {
    // Keep popular clean: show up to 2, then "+N"
    final popular = _capWithRemainder(vm.mostPopularNumbers, cap: 4); // still fine
    final profitable = _capWithRemainder(vm.mostProfitableNumbers, cap: 4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CardShell(
            child: _MetricBlock(
              label: 'Most Popular',
              numbers: popular.items,
              remainder: popular.remainder,
              totalCount: vm.mostPopularNumbers.length,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CardShell(
            child: _MetricBlock(
              label: 'Most Profitable',
              numbers: profitable.items,
              remainder: profitable.remainder,
              totalCount: vm.mostProfitableNumbers.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.numbers,
    required this.remainder,
    required this.totalCount,
  });

  final String label;
  final List<int> numbers;
  final int remainder;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    //final isAll = totalCount == 8;

    final labelStyle = t.labelSmall?.copyWith(
      fontSize: 10,
      height: 1.0,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
      color: Colors.white.withOpacityCompat(0.62),
    );

    final dashStyle = t.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 12,
      height: 1.0,
      color: Colors.white.withOpacityCompat(0.90),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: 8),

        // Fixed-height “value lane” keeps both columns aligned and prevents jumping.
        SizedBox(
          height: 36,
          child: Align(
            alignment: Alignment.centerLeft,
            child: numbers.isEmpty
                ? Text('—', style: dashStyle)
                // : isAll
                // ? Text('ALL', style: dashStyle)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final n in numbers) ...[NumberChip(n), const SizedBox(width: 3)],
                      if (remainder > 0) _MoreChip(remainder),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip(this.moreCount);
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),

      child: Text(
        '+$moreCount',
        style: t.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.0,
          color: Colors.white.withOpacityCompat(0.85),
        ),
      ),
    );
  }
}

class _Capped {
  const _Capped(this.items, this.remainder);
  final List<int> items;
  final int remainder;
}

_Capped _capWithRemainder(List<int> items, {required int cap}) {
  if (items.length <= cap) return _Capped(items, 0);
  return _Capped(items.sublist(0, cap), items.length - cap);
}
