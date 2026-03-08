import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/game/game_db_model.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_row_core_vm.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

enum PredictionOutcome { correct, miss, progress }

@immutable
class ProfilePredictionRowVM {
  const ProfilePredictionRowVM({
    required this.core,
    required this.gameEpoch,
    required this.tier,
    required this.epochLabel,
    required this.tierLabel,
    required this.outcome,
    required this.ticketsEarned,
    required this.selections,
    required this.wagerLamports,
    required this.createdAt,
    required this.isClaimed,
    this.winningNumber,
    this.totalPotLamports,
    this.arweaveUrl,
    this.payoutLamports,
    this.percentOfPotText,
    this.canClaim = false,
    this.winners,
    this.claimedAt,
  });

  final PredictionRowCore core;

  final BigInt gameEpoch;
  final int tier;

  final String epochLabel;
  final String tierLabel;

  final PredictionOutcome outcome;

  final int ticketsEarned;

  /// Header UI (matches screenshot)
  final List<int> selections; // chips
  final BigInt wagerLamports; // "0.12 SOL"
  final DateTime createdAt; // "2/11/2026, 12:21 PM"

  final bool isClaimed;

  /// Resolved / proof info
  final int? winningNumber; // null if not resolved
  final BigInt? totalPotLamports; // null if not resolved
  final String? arweaveUrl;

  /// Win details (optional until you fetch expanded data)
  final BigInt? payoutLamports;
  final String? percentOfPotText;
  final bool canClaim;
  final DateTime? claimedAt;

  final List<ApiWinnerRow>? winners;

  String get titleLine => '$epochLabel • $tierLabel';

  String get statusText {
    switch (outcome) {
      case PredictionOutcome.correct:
        return 'CORRECT';
      case PredictionOutcome.miss:
        return 'MISS';
      case PredictionOutcome.progress:
        return 'IN PROGRESS';
    }
  }

  Color get statusColor {
    switch (outcome) {
      case PredictionOutcome.correct:
        return const Color(0xFF63E06A);
      case PredictionOutcome.miss:
        return const Color(0xFFFF4D4D);
      case PredictionOutcome.progress:
        return Colors.orangeAccent.withOpacityCompat(0.92);
    }
  }

  String get wagerText => '${lamportsToSolText(wagerLamports)} SOL';

  String get totalPotText {
    final pot = totalPotLamports;
    if (pot == null) return '—';
    return '${lamportsToSolText(pot)} SOL';
  }

  String get payoutText {
    final p = payoutLamports;
    if (p == null) return '—';
    return '${lamportsToSolText(p)} SOL';
  }

  ProfilePredictionRowVM copyWith({
    PredictionOutcome? outcome,
    int? ticketsEarned,
    int? winningNumber,
    BigInt? totalPotLamports,
    String? arweaveUrl,
    BigInt? payoutLamports,
    String? percentOfPotText,
    bool? canClaim,
    bool? isClaimed,
    DateTime? claimedAt,
    List<ApiWinnerRow>? winners,
  }) {
    return ProfilePredictionRowVM(
      core: core,
      gameEpoch: gameEpoch,
      tier: tier,
      epochLabel: epochLabel,
      tierLabel: tierLabel,
      outcome: outcome ?? this.outcome,
      ticketsEarned: ticketsEarned ?? this.ticketsEarned,
      selections: selections,
      wagerLamports: wagerLamports,
      createdAt: createdAt,
      isClaimed: isClaimed ?? this.isClaimed,
      winningNumber: winningNumber ?? this.winningNumber,
      totalPotLamports: totalPotLamports ?? this.totalPotLamports,
      arweaveUrl: arweaveUrl ?? this.arweaveUrl,
      payoutLamports: payoutLamports ?? this.payoutLamports,
      percentOfPotText: percentOfPotText ?? this.percentOfPotText,
      canClaim: canClaim ?? this.canClaim,
      claimedAt: claimedAt ?? this.claimedAt,
      winners: winners ?? this.winners,
    );
  }
}
