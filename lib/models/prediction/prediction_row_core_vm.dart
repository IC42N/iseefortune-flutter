import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

class PredictionRowCore {
  PredictionRowCore({
    required this.pda,
    required this.playerLabel,
    required this.picks,
    required this.totalLamports,
    required this.lamportsPerPick,
    required this.lastUpdatedAtTs,
  });

  final String pda; // prediction PDA pubkey
  final String playerLabel;
  final List<int> picks;
  final BigInt totalLamports;
  final BigInt lamportsPerPick;
  final int lastUpdatedAtTs;

  int get primary => picks.isNotEmpty ? picks.first : 0;
  int get pickCount => picks.isNotEmpty ? picks.length : 1;
  int get pick => primary;

  BigInt get perPickLamports => lamportsPerPick;

  String get amountText => '${lamportsToSolText(perPickLamports)} SOL';

  String get pickRangeText {
    if (picks.isEmpty) return '—';
    if (picks.length == 1) return '${picks.first}';
    return '${picks.first}~${picks.last}';
  }

  Color get badgeColor => numberColor(primary, intensity: 0.98, saturation: 0.90);

  String get predictionPda => pda;
  String get predictionPdaShort => _truncateMiddle(pda, 4);

  String get timeLine {
    final dt = DateTime.fromMillisecondsSinceEpoch(lastUpdatedAtTs * 1000, isUtc: true).toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final h = ((dt.hour % 12) == 0 ? 12 : (dt.hour % 12)).toString();
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$mm/$dd/$yyyy, $h:$m $ampm';
  }

  static String _truncateMiddle(String s, int keep) {
    if (s.length <= keep * 2 + 3) return s;
    return '${s.substring(0, keep)}...${s.substring(s.length - keep)}';
  }
}
