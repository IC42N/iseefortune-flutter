// lib/ui/profile/profile_modal.dart
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/models/profile/profile_prediction_context.dart';
import 'package:iseefortune_flutter/models/profile/profile_view_model.dart';
import 'package:iseefortune_flutter/providers/game/resolved_game_cache_provider.dart';
import 'package:iseefortune_flutter/providers/game_history_provider.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_predictions_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_stats_provider.dart';
import 'package:iseefortune_flutter/services/epoch_clock_service.dart';
import 'package:iseefortune_flutter/ui/profile/helpers/helpers.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/performance_tile.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/prediction_accordian_list.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/stat_tile.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/numbers/pot.dart';
import 'package:provider/provider.dart';

class ProfileModal extends StatelessWidget {
  const ProfileModal({super.key, required this.vm, required this.isSelf, required this.handle});

  final ProfileViewModel vm;
  final bool isSelf;
  final String handle;

  @override
  Widget build(BuildContext context) {
    // ------------------------
    // Stats (API cached)
    // ------------------------
    final stats = context.watch<ProfileStatsProvider>().getCached(handle);
    final clock = context.watch<EpochClockService>();
    final history = context.watch<GameHistoryProvider>();
    final ctx = ProfilePredictionContext(
      currentEpoch: BigInt.from(clock.state?.epoch ?? 0),
      winningByEpoch: history.winningByEpoch,
    );

    // ------------------------
    // Predictions (RPC / WS)
    // ------------------------
    final predProv = context.watch<PlayerPredictionsProvider>();
    final predLoading = predProv.isLoading;
    final predErr = predProv.lastError;
    final rows = predProv.buildRows(ctx);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 110, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ======================
          // Top Stat Tiles
          // ======================
          Row(
            children: [
              Expanded(
                child: StatTile(
                  color: const Color(0xFFAEE3A6),
                  value: '${stats?.totalWins ?? 0}',
                  label: 'CORRECT',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: StatTile(
                  color: const Color(0xFFB85B5B),
                  value: '${stats?.totalLosses ?? 0}',
                  label: 'MISS',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: StatTile(color: const Color(0xFFE1D88E), value: '${vm.xp}', label: 'XP'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: StatTile(color: const Color(0xFF9FB1C4), value: '${vm.tickets}', label: 'TICKETS'),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ======================
          // Performance Header
          // ======================
          Center(
            child: Text(
              'PERFORMANCE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withOpacityCompat(0.55),
                fontSize: 13,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ======================
          // Performance Tiles
          // ======================
          Row(
            children: [
              Expanded(
                child: PerformanceTile(
                  value: lastResultText(stats),
                  label: 'LAST PREDICTION',
                  valueColor: lastResultColor(stats),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: PerformanceTile(value: '${stats?.bestWinStreak ?? 0}', label: 'BEST WIN STREAK'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: PerformanceTile(
                  value: stats == null ? '-' : profitTextFromStats(stats),
                  label: 'TOTAL PROFIT',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ======================
          // Predictions Section
          // ======================

          // Error (only show if we have nothing yet)
          if (predErr != null && rows.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  'Failed to load predictions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ),

            // Loading (ONLY if we have nothing yet)
          ] else if (predLoading && rows.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldColor.withOpacityCompat(0.85)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading predictions…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),

            // Empty state
          ] else if (rows.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  isSelf ? 'No predictions yet.' : 'No recent predictions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ),

            // Accordion list
          ] else ...[
            PredictionAccordionList(
              rows: rows,
              onExpandFetch: (row) async {
                final predProv = context.read<PlayerPredictionsProvider>();
                final pda = row.core.pda;

                if (predProv.hasOverride(pda)) return;

                // Determine if row is in progress.
                final activeChain = context
                    .read<LiveFeedProvider>()
                    .currentGameEpochOrZero; // == firstEpochInChain
                final isInProgress = row.gameEpoch == activeChain;

                if (isInProgress) {
                  final updated = row.copyWith(
                    outcome: PredictionOutcome.progress, // or whatever your VM uses
                    canClaim: false,
                    // optionally set some “expanded text” field if you have one
                  );
                  predProv.upsertRowOverrideForPda(pda, updated);
                  return;
                }

                final game = await context.read<ResolvedGameCacheProvider>().getOrFetch(
                  epoch: row.gameEpoch.toInt(),
                  tier: row.tier,
                );

                icLogger.i(
                  "Fetched game details for epoch ${row.gameEpoch}, "
                  "tier ${row.tier} on expand: ${game.toJson()}",
                );

                final currentEpoch = ctx.currentEpoch; // from your ProfilePredictionContext

                final outcome = computeOutcome(
                  currentEpoch: currentEpoch,
                  gameEpoch: row.gameEpoch,
                  selections: row.selections,
                  winningNumber: game.winningNumber,
                );

                final canClaim = computeCanClaim(outcome: outcome, isClaimed: row.isClaimed);
                final ticketsEarned = game.tickets
                    .where((t) => t.player == handle)
                    .fold<int>(0, (sum, t) => sum + t.rewarded);

                // payout (if winner entry exists for this handle)
                BigInt? payoutLamports;
                String? percentText;

                if (outcome == PredictionOutcome.correct) {
                  final winner = game.winners
                      .where((w) => w.player == handle)
                      .cast<dynamic>()
                      .firstWhere((w) => true, orElse: () => null);

                  if (winner != null) {
                    payoutLamports = winner.payoutLamports;
                    percentText = percentOfPotText(payoutLamports!, game.netPotLamports);
                  }
                }

                final updated = row.copyWith(
                  winningNumber: game.winningNumber,
                  totalPotLamports: game.netPotLamports,
                  arweaveUrl: game.arweaveResultsUri,
                  outcome: outcome,
                  canClaim: canClaim,
                  ticketsEarned: ticketsEarned,
                  payoutLamports: payoutLamports,
                  percentOfPotText: percentText,
                );

                predProv.upsertRowOverrideForPda(pda, updated);
              },
            ),
          ],
        ],
      ),
    );
  }
}
