// lib/ui/history/widgets/resolved_game_panel.dart
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/history/widgets/colored_title_bar.dart';
import 'package:iseefortune_flutter/ui/history/widgets/game_box.dart';
import 'package:iseefortune_flutter/ui/history/widgets/glass_card.dart';
import 'package:iseefortune_flutter/ui/history/widgets/info_row.dart';
import 'package:iseefortune_flutter/ui/history/widgets/mini_stats_card.dart';
import 'package:iseefortune_flutter/ui/history/widgets/rollover_card.dart';
import 'package:iseefortune_flutter/ui/history/widgets/section_header.dart';
import 'package:iseefortune_flutter/ui/history/widgets/table_header.dart';
import 'package:iseefortune_flutter/ui/history/widgets/tickets_table.dart';
import 'package:iseefortune_flutter/ui/history/widgets/winners_table.dart';
import 'package:iseefortune_flutter/ui/history/widgets/winning_number_card.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/solana/fee.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';
import 'package:iseefortune_flutter/utils/solana/pubkey.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/providers/game_history_provider.dart';
import 'package:iseefortune_flutter/providers/game/resolved_game_panel_provider.dart';
import 'package:iseefortune_flutter/models/game/game_unified_model.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class ResolvedGamePanel extends StatelessWidget {
  const ResolvedGamePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedEpoch = context.select<GameHistoryProvider, BigInt?>((p) => p.selectedEpoch);
    final historyLoading = context.select<GameHistoryProvider, bool>((p) => p.isLoading);
    final hasRows = context.select<GameHistoryProvider, bool>((p) => p.winningHistory.isNotEmpty);

    final resolvedLoading = context.select<ResolvedGamePanelProvider, bool>((p) => p.isLoading);
    final resolvedErr = context.select<ResolvedGamePanelProvider, Object?>((p) => p.lastError);
    final game = context.select<ResolvedGamePanelProvider, ResolvedGameHistoryModel?>((p) => p.current);

    // Keep calm during initial history load.
    if (!hasRows && historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedEpoch == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassCard(
          child: Text(
            'Select an epoch above.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    // resolved game loading
    if (game == null && resolvedLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // resolved game error
    if (game == null && resolvedErr != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassCard(
          child: Text(
            'Failed to load resolved game.\n$resolvedErr',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    if (game == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassCard(
          child: Text(
            'No resolved game data for epoch ${selectedEpoch.toString()}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    icLogger.w(game.toJson());

    final winningNumber = game.winningNumber;
    final hue = hueForNumber(winningNumber);
    final pal = RowHuePalette(hue);

    final netSol = lamportsToSolText(game.netPotLamports);
    final feeSol = lamportsToSolText(game.feeLamports);
    final feePercentText = feeBpsToPercent(game.feeBps);

    final winners = game.winners;
    final tickets = game.tickets;

    // These are NOT in your payload (yet) -> show placeholder
    final String totalPredictionsText = game.totalPredictions.toString();
    final String totalMissedText = game.losersCount.toString();

    // Tickets: show total recipients + total tickets awarded (if your row has rewarded count)
    final totalTickets = tickets.fold<int>(0, (sum, t) => sum + (t.rewarded));
    final ticketsRecipients = tickets.length;

    // Claimed is also not in your payload currently
    //final String claimedText = '—';

    return GameBox(
      hueDeg: hue.toInt(),
      child: Scrollbar(
        thickness: 3,
        radius: const Radius.circular(6),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'RESOLVED GAME',
                epoch: game.gameEpoch,
                tier: 'Tier ${game.tier}',
                rightButtonText: 'Result Verification',
                color: pal.pkColor,
                onRightTap: () async {
                  final uri = Uri.parse('https://verify.iseefortune.com/?epoch=${game.epoch}');
                  if (!await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication, // opens system browser
                  )) {
                    icLogger.w('Could not launch verifier URL');
                  }
                },
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 92, // pick the height you want for this “top row”
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 1,
                      child: WinningNumberCard(winningNumber: winningNumber, palette: pal),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: game.isRollover
                          ? RolloverCard(
                              palette: pal,
                              reason: game.rolloverReason, // e.g. "RolloverNumber" or your pretty label
                            )
                          : GlassCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: InfoRow(leftLabel: 'Net prize pool', rightValue: '$netSol SOL'),
                                  ),

                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.white.withOpacityCompat(0.08),
                                  ),

                                  Expanded(
                                    child: InfoRow(
                                      leftLabel: 'Fee',
                                      rightValue: '$feeSol SOL ($feePercentText)',
                                    ),
                                  ),

                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.white.withOpacityCompat(0.08),
                                  ),

                                  Expanded(
                                    child: InfoRow(
                                      leftLabel: 'Total Predictions',
                                      rightValue: totalPredictionsText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              if (!game.isRollover) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MiniStatCard(label: 'Total winners', value: '${game.winnersCount}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MiniStatCard(label: 'Total Missed', value: totalMissedText),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MiniStatCard(
                        label: 'Total Tickets',
                        value: tickets.isEmpty ? '0' : '$totalTickets',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Center(
                        child: InfoRow(
                          leftLabel: 'Blockhash used',
                          rightValue: game.blockhash.isEmpty ? '—' : shortBlockHash(game.blockhash),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.white.withOpacityCompat(0.08)),

                    SizedBox(
                      height: 38,
                      child: Center(
                        child: InfoRow(
                          leftLabel: 'Slot used',
                          rightValue: game.endSlot == BigInt.zero ? '—' : game.endSlot.toString(),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.white.withOpacityCompat(0.08)),

                    SizedBox(
                      height: 38,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                'Zero Trust Verify',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('https://explorer.solana.com/block/${game.endSlot}');
                                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                    debugPrint('Could not launch explorer URL');
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Solana Explorer',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: pal.pkColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.open_in_new, size: 16, color: pal.pkColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!game.isRollover) ...[
                const SizedBox(height: 10),
                ColoredTitleBar(title: 'WINNERS AND TICKET AWARDS', hueDeg: hue.toInt()),
                const SizedBox(height: 10),

                // Winners table
                GlassCard(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TableHeader(title: 'Winners', countText: '(${winners.length})'),
                      if (winners.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            game.source == ResolvedGameSource.api
                                ? 'No winners listed.'
                                : 'Chain fallback does not include winner rows.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        )
                      else
                        WinnersTable(winners: winners, lamportsToSolText: lamportsToSolText),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Tickets table
                GlassCard(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TableHeader(
                        title: 'Tickets',
                        countText: tickets.isEmpty ? '(0 recipients)' : '($ticketsRecipients recipients)',
                      ),
                      if (tickets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No tickets awarded.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        )
                      else
                        TicketsTable(tickets: tickets),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                GlassCard(
                  child: Text(
                    'This epoch rolled over. No winners or tickets were generated.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
