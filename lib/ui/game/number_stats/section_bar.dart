import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/stats_anim.dart';
import 'package:iseefortune_flutter/ui/shared/number_decoration.dart';

class DistributionBars extends StatelessWidget {
  const DistributionBars({super.key, required this.vm});

  final LiveFeedVM vm;

  static const double _barHeight = 10;
  static const double _gap = 6;

  // “Circle segment” width when count == 0 and total > 0
  static const double _zeroCircleSize = 10;

  @override
  Widget build(BuildContext context) {
    // Keep order = selectable order (8 numbers)
    final items = vm.selectableNumbers
        .map((n) => vm.stats.firstWhere((s) => s.number == n))
        .toList(growable: false);

    final total = vm.totalPredictions;

    return SizedBox(
      height: _barHeight,
      child: LayoutBuilder(
        builder: (context, c) {
          final totalWidth = c.maxWidth;
          final gapsWidth = _gap * (items.length - 1);

          // Case 1: no predictions yet => evenly split across all 8
          if (total <= 0) {
            final w = (totalWidth - gapsWidth) / items.length;
            return _row(items, (s) => w, totalPredictions: total);
          }

          // Case 2: predictions exist:
          // - zeros become fixed circles (width = height)
          // - remaining width distributed proportionally across >0 segments
          final zeroItems = items.where((s) => s.count == 0).toList(growable: false);
          final nonZeroItems = items.where((s) => s.count > 0).toList(growable: false);

          final zeroWidthTotal = zeroItems.length * _zeroCircleSize;
          final available = (totalWidth - gapsWidth - zeroWidthTotal).clamp(0.0, double.infinity);

          final nonZeroTotal = nonZeroItems.fold<int>(0, (sum, s) => sum + s.count);

          // Defensive fallback (shouldn't happen if total>0)
          if (nonZeroTotal == 0) {
            final w = (totalWidth - gapsWidth) / items.length;
            return _row(items, (s) => w, totalPredictions: total);
          }

          return _row(items, (s) {
            if (s.count == 0) return _zeroCircleSize;
            return available * (s.count / nonZeroTotal);
          }, totalPredictions: total);
        },
      ),
    );
  }

  Widget _row(
    List<NumberStatVM> items,
    double Function(NumberStatVM s) widthFor, {
    required int totalPredictions,
  }) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _Segment(
            stat: items[i],
            width: widthFor(items[i]),
            height: _barHeight,
            // when total > 0 and count==0 => render as perfect circle
            forceCircle: totalPredictions > 0 && items[i].count == 0,
          ),
          if (i != items.length - 1) const SizedBox(width: _gap),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.stat, required this.width, required this.height, required this.forceCircle});

  final NumberStatVM stat;
  final double width;
  final double height;
  final bool forceCircle;

  @override
  Widget build(BuildContext context) {
    final w = forceCircle ? height : width;
    return AnimatedContainer(
      duration: kStatsAnimDuration,
      curve: kStatsAnimCurve,
      width: w,
      height: height,
      decoration: numberBarDecoration(
        stat.number,
        intensity: (stat.count == 0) ? kBarZeroIntensity : kBarIntensity,
        isZero: forceCircle,
      ),
    );
  }
}
