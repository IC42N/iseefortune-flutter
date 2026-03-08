import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/services/predictions/prediction_live_row_vm.dart';
import 'package:iseefortune_flutter/ui/game/predictions/empty_state.dart';
import 'package:iseefortune_flutter/ui/shared/game_tabs.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/providers/predictions_provider.dart';
import 'package:iseefortune_flutter/services/predictions/prediction_row_vm_builder.dart';
import 'package:iseefortune_flutter/ui/game/predictions/prediction_row.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class PredictionsPage extends StatefulWidget {
  const PredictionsPage({super.key});

  @override
  State<PredictionsPage> createState() => _PredictionsPageState();
}

class _PredictionsPageState extends State<PredictionsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Pull-to-refresh handler:
  /// Forces the provider to re-hydrate + re-subscribe for the current epoch/tier.
  Future<void> _refresh() async {
    await context.read<PredictionsProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'PREDICTIONS',
                style: t.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.goldColor.withOpacityCompat(0.45),
                  letterSpacing: 0.7,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: GameStyleTabs(
                controller: _tabs,
                labels: const ['Latest', 'Most Committed'],
                onTapIndex: (i) {},
              ),
            ),

            const SizedBox(height: 6),

            // Body
            Expanded(
              child: Consumer<PredictionsProvider>(
                builder: (context, provider, _) {
                  // Build VMs once, reuse for both tabs
                  final latestRows = provider.recentEntries
                      .map((e) => buildLivePredictionRowVM(pubkey: e.key, p: e.value))
                      .toList(growable: false);

                  final mostCommitted = () {
                    final copy = List<LivePredictionRowVM>.from(latestRows);
                    copy.sort((a, b) => b.core.totalLamports.compareTo(a.core.totalLamports));
                    return copy.take(math.min(50, copy.length)).toList(growable: false);
                  }();

                  return TabBarView(
                    controller: _tabs,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _PredictionsFeed(
                        tab: _PredTab.latest,
                        rows: latestRows,
                        isLoading: provider.isLoading,
                        onRefresh: _refresh,
                      ),
                      _PredictionsFeed(
                        tab: _PredTab.top,
                        rows: mostCommitted,
                        isLoading: provider.isLoading,
                        onRefresh: _refresh,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PredTab { latest, top }

/// Dumb rendering widget:
/// - Receives rows + loading + onRefresh
/// - Handles empty/loading UI
/// - Owns the RefreshIndicator (so pull-to-refresh works everywhere)
class _PredictionsFeed extends StatelessWidget {
  const _PredictionsFeed({
    required this.tab,
    required this.rows,
    required this.isLoading,
    required this.onRefresh,
  });

  final _PredTab tab;
  final List<LivePredictionRowVM> rows;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // Loading state (no rows yet)
    if (isLoading && rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: const _EmptyScrollable(title: 'Loading…', subtitle: ''),
      );
    }

    // Empty state
    if (rows.isEmpty) {
      final title = tab == _PredTab.latest ? 'Awaiting new predictions' : 'No contributors yet';
      final subtitle = tab == _PredTab.latest
          ? 'A new epoch has begun.'
          : 'Once bets arrive, you\'ll see top contributors here.';

      return RefreshIndicator(
        onRefresh: onRefresh,
        child: _EmptyScrollable(title: title, subtitle: subtitle),
      );
    }

    // Normal list
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, i) {
          final vm = rows[i];

          // Animate updates by changing the key when lastUpdatedAtTs changes
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: anim.drive(Tween(begin: const Offset(0, 0.08), end: Offset.zero)),
                  child: child,
                ),
              );
            },
            child: PredictionRow(
              key: ValueKey('${vm.core.pda}:${vm.core.lastUpdatedAtTs}'),
              vm: vm,
              isTop: tab == _PredTab.top,
            ),
          );
        },
      ),
    );
  }
}

/// Makes RefreshIndicator work even when empty,
/// and centers the empty state within the available pane.
class _EmptyScrollable extends StatelessWidget {
  const _EmptyScrollable({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: const Alignment(0, -0.20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: EmptyState(title: title, subtitle: subtitle),
              ),
            ),
          ),
        );
      },
    );
  }
}
