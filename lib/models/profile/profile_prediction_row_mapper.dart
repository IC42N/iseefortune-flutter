import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_row_core_vm.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/models/profile/profile_prediction_context.dart';

// Profile predictions list
// Maps from PredictionModel (core data from on-chain + API) to ProfilePredictionRowVM (UI-ready data for profile screen rows).
ProfilePredictionRowVM mapPredictionModelToProfileRow({
  required PredictionModel m,
  required String predictionPda, // you likely know this from fetch result key
  required ProfilePredictionContext ctx,
  String playerLabel = '',
  String? arweaveUrl,
  int ticketsEarned = 0,
  int? winningNumber,
  BigInt? totalPotLamports,
  BigInt? payoutLamports,
  bool canClaim = false,
  PredictionOutcome outcome = PredictionOutcome.progress,
}) {
  final epochLabel = m.epoch.toString();
  final tierLabel = 'Tier ${m.tier}';

  final picks = m.activeSelections;

  final winningNumber = ctx.winningByEpoch[m.epoch];

  // resolved if we have a winning number for that epoch
  final isResolved = winningNumber != null;

  // winner if resolved and picks contains winning number
  final isWinner = isResolved && picks.contains(winningNumber);

  final outcome = isResolved
      ? (isWinner ? PredictionOutcome.correct : PredictionOutcome.miss)
      : PredictionOutcome.progress;

  // claimable only if won, resolved, and not already claimed
  final canClaim = isWinner && !m.isClaimed;

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
    outcome: outcome,
    ticketsEarned: 0,
    winningNumber: winningNumber,
    totalPotLamports: null,
    arweaveUrl: null,
    selections: picks,
    wagerLamports: m.lamports,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m.placedAtTs * 1000, isUtc: true),
    payoutLamports: null,
    canClaim: canClaim,
    isClaimed: m.isClaimed,
  );
}
