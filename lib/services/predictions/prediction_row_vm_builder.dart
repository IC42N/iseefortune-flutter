import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/services/predictions/prediction_live_row_vm.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_row_core_vm.dart';
import 'package:iseefortune_flutter/utils/solana/pubkey.dart';

// Builds a PredictionRowVM from a PredictionModel + its PDA pubkey.
// Used in the live predicitons feed only.
LivePredictionRowVM buildLivePredictionRowVM({required String pubkey, required PredictionModel p}) {
  final playerLabel = getHandleFromPubkey(p.player);
  final core = PredictionRowCore(
    pda: pubkey,
    playerLabel: playerLabel,
    picks: p.activeSelections,
    totalLamports: p.lamports,
    lamportsPerPick: p.lamportsPerNumber,
    lastUpdatedAtTs: p.lastUpdatedAtTs,
  );

  // If you have better “locked / inProgress” info, wire it here.
  // For now, treat everything in predictions feed as in progress.
  const status = LivePredictionStatus.inProgress;

  return LivePredictionRowVM(core: core, status: status);
}
