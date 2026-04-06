import 'package:iseefortune_flutter/models/game_resolution/game_resolution_profile_result.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_row_core_vm.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/models/profile/profile_prediction_context.dart';
import 'package:iseefortune_flutter/utils/epoch_display.dart';

// Profile predictions list
// Maps from PredictionModel (core data from on-chain + API)
// to ProfilePredictionRowVM (UI-ready data for profile screen rows).
ProfilePredictionRowVM mapPredictionModelToProfileRow({
  required PredictionModel m,
  required String predictionPda,
  required ProfilePredictionContext ctx,
  required ResolvedGameProfileResult? resolved,
  String playerLabel = '',
}) {
  final epochLabel = formatEpochDisplay(firstEpochInChain: m.gameEpoch, epoch: m.epoch);

  final tierLabel = 'Tier ${m.tier}';
  final picks = m.activeSelections;

  final resolvedWinningNumber = resolved?.winningNumber;
  final isResolved = resolved != null && resolvedWinningNumber != null;

  final isWinner = isResolved && picks.contains(resolvedWinningNumber);

  final PredictionOutcome derivedOutcome;
  if (isResolved) {
    derivedOutcome = isWinner ? PredictionOutcome.correct : PredictionOutcome.miss;
  } else if (m.gameEpoch == ctx.currentEpoch) {
    derivedOutcome = PredictionOutcome.progress;
  } else {
    // Past game with missing resolved row should be rare.
    // Keep as progress until resolved data is available.
    derivedOutcome = PredictionOutcome.progress;
  }

  final derivedCanClaim = isWinner && !m.isClaimed;

  final core = PredictionRowCore(
    pda: predictionPda,
    playerLabel: playerLabel.isNotEmpty ? playerLabel : m.player,
    picks: picks,
    totalLamports: m.lamports,
    lamportsPerPick: m.lamportsPerNumber,
    lastUpdatedAtTs: m.lastActivityTs,
  );

  return ProfilePredictionRowVM(
    core: core,
    gameEpoch: m.gameEpoch,
    tier: m.tier,
    epochLabel: epochLabel,
    tierLabel: tierLabel,
    outcome: derivedOutcome,
    ticketsEarned: 0,
    winningNumber: resolvedWinningNumber,
    totalPotLamports: null,
    arweaveUrl: null,
    selections: picks,
    wagerLamports: m.lamports,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m.placedAtTs * 1000, isUtc: true),
    payoutLamports: null,
    canClaim: derivedCanClaim,
    isClaimed: m.isClaimed,
  );
}
