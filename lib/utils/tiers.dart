import 'package:iseefortune_flutter/models/tier_model.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

String tierBetRangeText(TierSettings? t) {
  if (t == null) return '—';

  // CHANGE THESE TWO FIELD NAMES to match TierSettings.
  final BigInt minLamports = t.minBetLamports;
  final BigInt maxLamports = t.maxBetLamports;

  return '${lamportsToSolTrim(minLamports)}~${lamportsToSolTrim(maxLamports)} SOL';
}

String tierNameFromTier(int? tier) {
  switch (tier) {
    case 1:
      return 'Dust';
    case 2:
      return 'Spark';
    case 3:
      return 'Star';
    case 4:
      return 'Nebula';
    case 5:
      return 'Supernova';
    default:
      return 'Unknown';
  }
}
