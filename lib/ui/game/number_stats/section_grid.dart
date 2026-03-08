import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/each_cell.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/progress_bar.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class NumberStatsGrid extends StatelessWidget {
  const NumberStatsGrid({super.key, required this.vm});
  final LiveFeedVM vm;

  @override
  Widget build(BuildContext context) {
    final stats = vm.stats; // already 8

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.85,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _NumberStatCard(stat: stats[i]),
    );
  }
}

class _NumberStatCard extends StatelessWidget {
  const _NumberStatCard({required this.stat});
  final NumberStatVM stat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final pct01 = (stat.percent / 100).clamp(0.0, 1.0);

    final countStyle = t.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      height: 1.0,
      color: AppColors.goldColor,
      letterSpacing: -0.2,
    );

    final subStyle = t.labelSmall?.copyWith(
      fontSize: 10,
      height: 1.0,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w800,
      color: Colors.white.withOpacityCompat(0.72),
    );

    return NumberStatCell(
      number: stat.number,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: chip + count
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              NumberChip(stat.number, size: 30, intensity: 0.9),

              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IgnorePointer(
                    child: Opacity(
                      opacity: 0.8, // subtle, not competing
                      child: SvgPicture.asset(
                        'assets/svg/balls/ball-icon.svg',
                        colorFilter: ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
                        width: 16,
                        height: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('${stat.count}', style: countStyle),
                ],
              ),
            ],
          ),

          const Spacer(),

          Text('${stat.percent.toStringAsFixed(1)}% OF PREDICTIONS', style: subStyle),

          const SizedBox(height: 8),

          NumberProgressBar(number: stat.number, pct01: pct01, height: 7),
        ],
      ),
    );
  }
}
