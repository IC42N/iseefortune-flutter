import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/game/game_pda_model.dart';
import 'package:iseefortune_flutter/utils/solana/fee.dart';
import 'game_db_model.dart'; // ApiResolvedGameDto

enum ResolvedGameSource { api, chain }

@immutable
class ResolvedGameHistoryModel {
  const ResolvedGameHistoryModel({
    required this.gameEpoch,
    required this.epoch,
    required this.tier,
    required this.winningNumber,
    required this.netPotLamports,
    required this.grossPotLamports,
    required this.feeLamports,
    required this.feeBps,
    required this.winnersCount,
    required this.losersCount,
    required this.totalPredictions,
    required this.secondaryRolloverNumber,
    required this.arweaveResultsUri,
    required this.resolveTxSignature,
    required this.updatedAt,
    required this.source,
    required this.blockhash,
    required this.endSlot,
    required this.winners,
    required this.tickets,
    required this.isRollover,
    required this.rolloverReason,
  });

  final String gameEpoch;
  final int epoch;
  final int tier;
  final int winningNumber;

  final BigInt netPotLamports;
  final BigInt grossPotLamports;
  final BigInt feeLamports;
  final int feeBps;

  final int winnersCount;
  final int losersCount;
  final int totalPredictions;

  final int secondaryRolloverNumber;

  final String? arweaveResultsUri;
  final String? resolveTxSignature;

  final DateTime? updatedAt;

  final ResolvedGameSource source;

  final String blockhash;
  final BigInt endSlot;

  /// Optional: api extras winners
  final List<ApiWinnerRow> winners;
  final List<ApiTicketRow> tickets;

  final bool isRollover;
  final String rolloverReason;

  factory ResolvedGameHistoryModel.fromApi(ApiResolvedGameDto dto) {
    return ResolvedGameHistoryModel(
      gameEpoch: dto.core.firstEpoch != dto.core.lastEpoch
          ? "${dto.core.firstEpoch}~${dto.core.lastEpoch}"
          : dto.core.gameEpoch.toString(),
      epoch: dto.gameEpoch,
      tier: dto.tier,
      winningNumber: dto.core.winningNumber,
      netPotLamports: dto.core.netPotLamports,
      grossPotLamports: dto.core.grossPotLamports,
      feeLamports: dto.core.feeLamports,
      feeBps: dto.core.feeBps,
      winnersCount: dto.core.winnersCount,
      losersCount: dto.core.losersCount,
      totalPredictions: dto.core.winnersCount + dto.core.losersCount,
      secondaryRolloverNumber: dto.core.secondaryRolloverNumber,
      arweaveResultsUri: dto.core.arweaveResultsUri,
      resolveTxSignature: dto.core.resolveTxSignature,
      updatedAt: dto.core.updatedAt ?? dto.core.createdAt,
      source: ResolvedGameSource.api,
      blockhash: dto.core.rngBlockhashBase58,
      endSlot: dto.core.endSlot,
      winners: dto.extras.winners,
      tickets: dto.extras.tickets,
      isRollover: dto.isRollover,
      rolloverReason: rolloverReasonDescription(
        reason: dto.core.rolloverReasonText,
        winningNumber: dto.core.secondaryRolloverNumber,
      ),
    );
  }

  factory ResolvedGameHistoryModel.fromChain(ResolvedGameModel m) {
    return ResolvedGameHistoryModel(
      gameEpoch: m.firstEpochInChain != BigInt.zero && m.epoch != m.firstEpochInChain
          ? "${m.firstEpochInChain}~${m.epoch}"
          : m.epoch.toString(),
      epoch: m.epoch.toInt(),
      tier: m.tier,
      winningNumber: m.winningNumber,
      netPotLamports: m.netPrizePool, // chain naming
      grossPotLamports: m.netPrizePool + m.protocolFeeLamports,
      feeLamports: m.protocolFeeLamports,
      feeBps: m.feeBps != 0 ? m.feeBps : calculateFeeBps(m.netPrizePool, m.protocolFeeLamports),
      winnersCount: m.totalWinners,
      losersCount: m.totalBets - m.totalWinners,
      totalPredictions: m.totalBets,
      secondaryRolloverNumber: m.secondaryRolloverNumber,
      arweaveResultsUri: m.resultsUriString.isEmpty ? null : m.resultsUriString,
      resolveTxSignature: null, // chain account doesn't store it (unless you do)
      updatedAt: _tsToDate(m.lastUpdatedTs),
      source: ResolvedGameSource.chain,
      blockhash: m.rngBlockhashBase58,
      endSlot: m.rngEpochSlotUsed,
      winners: [],
      tickets: [],
      isRollover: m.isRollover,
      rolloverReason: rolloverReasonDescription(
        reason: m.rolloverReasonText,
        winningNumber: m.secondaryRolloverNumber,
      ),
    );
  }

  static DateTime? _tsToDate(int tsSeconds) {
    if (tsSeconds == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(tsSeconds * 1000, isUtc: true);
  }

  static String rolloverReasonDescription({required String reason, required int winningNumber}) {
    switch (reason) {
      case 'RolloverNumber':
        return 'The winning number was $winningNumber and it was a rollover number. '
            'The game continued into the next epoch.';

      case 'NoWinners':
        return 'There were no winners for this epoch. '
            'The prize pool carried forward to the next epoch.';

      default:
        return 'This game rolled over into the next epoch.';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'gameEpoch': gameEpoch,
      'epoch': epoch,
      'tier': tier,
      'winningNumber': winningNumber,
      'netPotLamports': netPotLamports.toString(),
      'grossPotLamports': grossPotLamports.toString(),
      'feeLamports': feeLamports.toString(),
      'feeBps': feeBps,
      'winnersCount': winnersCount,
      'losersCount': losersCount,
      'secondaryRolloverNumber': secondaryRolloverNumber,
      'arweaveResultsUri': arweaveResultsUri,
      'resolveTxSignature': resolveTxSignature,
      'updatedAt': updatedAt?.toIso8601String(),
      'source': source.name,
      'blockhash': blockhash,
      'endSlot': endSlot.toString(),
      'winners': winners.map((w) => _winnerToJson(w)).toList(),
      'tickets': tickets.map((t) => _ticketToJson(t)).toList(),
      'isRollover': isRollover,
      'rolloverReason': rolloverReason,
    };
  }

  Map<String, dynamic> _winnerToJson(ApiWinnerRow w) {
    return {
      'player': w.player,
      'wager_total_lamports': w.wagerTotalLamports.toString(),
      'wager_win_portion_lamports': w.wagerWinPortionLamports.toString(),
      'payout_lamports': w.payoutLamports.toString(),
      'changed_count': w.changedCount,
    };
  }

  Map<String, dynamic> _ticketToJson(ApiTicketRow t) {
    return {
      'player': t.player,
      'epoch': t.epoch,
      'tier': t.tier,
      'placed_slot': t.placedSlot.toString(),
      'lamports': t.lamports.toString(),
      'rewarded': t.rewarded,
    };
  }
}
