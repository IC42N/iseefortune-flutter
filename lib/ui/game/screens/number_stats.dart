import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_builder.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/section_bar.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/section_grid.dart';
import 'package:iseefortune_flutter/ui/game/number_stats/section_top.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

class NumberStatsPage extends StatelessWidget {
  const NumberStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final liveFeed = context.select<LiveFeedProvider, dynamic>((p) => p.liveFeed);
    final config = context.select<ConfigProvider, dynamic>((p) => p.config);

    if (liveFeed == null || config == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final LiveFeedVM vm = buildLiveFeedVM(
      liveFeed: liveFeed,
      primaryRollOverNumber: config.primaryRollOverNumber,
    );

    return NumberStatsView(vm: vm);
  }
}

/// Split “page vs view” so the page is just wiring.
class NumberStatsView extends StatelessWidget {
  const NumberStatsView({super.key, required this.vm});
  final LiveFeedVM vm;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              'CURRENT STATS',
              style: t.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.goldColor.withOpacityCompat(0.45),
                letterSpacing: 0.7,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // 1) Most Popular / Most Profitable
            TopRow(vm: vm),
            const SizedBox(height: 14),

            // 2) Color distribution bars
            DistributionBars(vm: vm),
            const SizedBox(height: 14),

            // 3) Main 2x4 grid (always 8 numbers)
            NumberStatsGrid(vm: vm),
          ],
        ),
      ),
    );
  }
}
