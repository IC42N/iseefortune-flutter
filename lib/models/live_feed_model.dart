import 'dart:typed_data';
import 'package:iseefortune_flutter/models/helper.dart';
import 'package:solana/solana.dart';
import 'package:solana_borsh/borsh.dart';
import 'package:solana_borsh/models.dart';
import 'package:solana_borsh/types.dart';

/// LiveFeed model (Anchor/Borsh)
/// ---------------------------------------------------------------------------
/// This MUST match the Rust struct field order + types exactly:
///
/// Rust:
///   u64 epoch
///   u64 first_epoch_in_chain
///   u64 total_lamports
///   u64 carried_over_lamports
///   u32 total_bets
///   u32 carried_over_bets
///   u64 bet_cutoff_slots
///   u8  tier
///   Pubkey treasury (32 bytes)
///   u8  epochs_carried_over
///   u8  bump
///   [u64;10] lamports_per_number
///   [u32;10] bets_per_number
///   u8  secondary_rollover_number
///   u16 current_fee_bps
///   [u8;61] _reserved
class LiveFeedModel extends BorshObject {
  LiveFeedModel({
    required this.epoch,
    required this.firstEpochInChain,
    required this.totalLamports,
    required this.carriedOverLamports,
    required this.totalBets,
    required this.carriedOverBets,
    required this.betCutoffSlots,
    required this.tier,
    required this.treasury,
    required this.epochsCarriedOver,
    required this.bump,
    required this.lamportsPerNumber,
    required this.betsPerNumber,
    required this.secondaryRolloverNumber,
    required this.currentFeeBps,
    required this.reserved,
  });

  // u64
  final BigInt epoch;
  final BigInt firstEpochInChain;
  final BigInt totalLamports;
  final BigInt carriedOverLamports;

  // u32
  final int totalBets;
  final int carriedOverBets;

  // u64
  final BigInt betCutoffSlots;

  // u8
  final int tier;

  // Pubkey (32 bytes)
  final Ed25519HDPublicKey treasury;

  // u8
  final int epochsCarriedOver;
  final int bump;

  // arrays
  final List<BigInt> lamportsPerNumber; // length 10, each u64
  final List<int> betsPerNumber; // length 10, each u32

  // u8, u16
  final int secondaryRolloverNumber;
  final int currentFeeBps;

  // [u8;61]
  final Uint8List reserved;

  // ---------------------------------------------------------------------------
  // Borsh schema
  // ---------------------------------------------------------------------------

  static BorshSchema get staticSchema => {
    'epoch': borsh.u64,
    'firstEpochInChain': borsh.u64,
    'totalLamports': borsh.u64,
    'carriedOverLamports': borsh.u64,
    'totalBets': borsh.u32,
    'carriedOverBets': borsh.u32,
    'betCutoffSlots': borsh.u64,
    'tier': borsh.u8,
    'treasury': borsh.pubkey,
    'epochsCarriedOver': borsh.u8,
    'bump': borsh.u8,
    'lamportsPerNumber': borsh.array(borsh.u64, 10),
    'betsPerNumber': borsh.array(borsh.u32, 10),
    'secondaryRolloverNumber': borsh.u8,
    'currentFeeBps': borsh.u16,
    'reserved': borsh.array(borsh.u8, 61), // fixed 61 bytes
  };

  @override
  BorshSchema get borshSchema => staticSchema;

  // ---------------------------------------------------------------------------
  // JSON mapping (used by solana_borsh deserialize callback)
  // ---------------------------------------------------------------------------

  factory LiveFeedModel.fromJson(Map<String, dynamic> json) {
    final treasuryPk = parsePubkey(json['treasury'], label: 'LiveFeed.treasury');

    final lamportsList = (json['lamportsPerNumber'] as List).map((v) => v as BigInt).toList(growable: false);

    final betsList = (json['betsPerNumber'] as List).map((v) => v as int).toList(growable: false);

    final reservedBytes = parseU8Array(json['reserved'], len: 61, label: 'LiveFeed.reserved');

    return LiveFeedModel(
      epoch: json['epoch'] as BigInt,
      firstEpochInChain: json['firstEpochInChain'] as BigInt,
      totalLamports: json['totalLamports'] as BigInt,
      carriedOverLamports: json['carriedOverLamports'] as BigInt,
      totalBets: json['totalBets'] as int,
      carriedOverBets: json['carriedOverBets'] as int,
      betCutoffSlots: json['betCutoffSlots'] as BigInt,
      tier: json['tier'] as int,
      treasury: treasuryPk,
      epochsCarriedOver: json['epochsCarriedOver'] as int,
      bump: json['bump'] as int,
      lamportsPerNumber: lamportsList,
      betsPerNumber: betsList,
      secondaryRolloverNumber: json['secondaryRolloverNumber'] as int,
      currentFeeBps: json['currentFeeBps'] as int,
      reserved: reservedBytes,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'epoch': epoch,
    'firstEpochInChain': firstEpochInChain,
    'totalLamports': totalLamports,
    'carriedOverLamports': carriedOverLamports,
    'totalBets': totalBets,
    'carriedOverBets': carriedOverBets,
    'betCutoffSlots': betCutoffSlots,
    'tier': tier,
    'treasury': treasury.bytes,
    'epochsCarriedOver': epochsCarriedOver,
    'bump': bump,
    'lamportsPerNumber': lamportsPerNumber,
    'betsPerNumber': betsPerNumber,
    'secondaryRolloverNumber': secondaryRolloverNumber,
    'currentFeeBps': currentFeeBps,
    'reserved': reserved,
  };
}
