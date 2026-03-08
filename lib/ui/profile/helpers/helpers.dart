import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/models/profile/profile_stats_model.dart';
import 'package:iseefortune_flutter/providers/claim/claim_provider.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

// ------------------------
// Helpers
// ------------------------
String profitTextFromStats(ProfileStatsModel s) {
  // Only show positive; if negative, show 0
  final rawSol = s.totalProfitLamports / 1e9;
  final sol = rawSol < 0 ? 0.0 : rawSol;
  return '${formatSol(sol)} SOL';
}

String lastResultText(ProfileStatsModel? stats) {
  if (stats == null) return '—';
  if (stats.lastResult.isEmpty) return '—';
  return stats.lastResult.toUpperCase();
}

Color lastResultColor(ProfileStatsModel? stats) {
  if (stats == null) return Colors.white60;

  switch (stats.lastResult.toUpperCase()) {
    case 'CORRECT':
      return const Color(0xFFAEE3A6);
    case 'WRONG':
      return const Color(0xFFB85B5B);
    default:
      return Colors.white60;
  }
}

PredictionOutcome computeOutcome({
  required BigInt currentEpoch,
  required BigInt gameEpoch,
  required List<int> selections,
  required int winningNumber,
}) {
  // still running
  if (gameEpoch >= currentEpoch) return PredictionOutcome.progress;

  // resolved
  final won = selections.contains(winningNumber);
  return won ? PredictionOutcome.correct : PredictionOutcome.miss;
}

bool computeCanClaim({required PredictionOutcome outcome, required bool isClaimed}) {
  // only winners can claim, and only if not already claimed
  return outcome == PredictionOutcome.correct && !isClaimed;
}

String claimedMainLine(ClaimState st) {
  final at = st.claimedAt;
  if (at == null) return 'Claimed';
  final days = DateTime.now().difference(at).inDays;
  if (days <= 0) return 'Claimed today';
  if (days == 1) return 'Claimed 1 day ago';
  return 'Claimed $days days ago';
}

String buttonText(ClaimState st) {
  switch (st.phase) {
    case ClaimPhase.preparing:
      return 'Preparing…';

    case ClaimPhase.awaitingSignature:
      return 'Sign in wallet…';

    case ClaimPhase.error:
    case ClaimPhase.idle:
      return 'Claim';

    case ClaimPhase.success:
      // Success never shows button in this design
      return 'Claim';
  }
}

String claimedDateLine(DateTime dt) {
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return 'Claimed on $y-$m-$d';
}
