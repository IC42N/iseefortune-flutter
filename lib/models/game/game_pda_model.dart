import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:solana_borsh/models.dart';
import 'package:solana_borsh/types.dart';
import 'package:solana/base58.dart';

/// Mirrors Rust ResolvedGame account (AFTER 8-byte Anchor discriminator).
///
/// Notes:
/// - `claimedBitmap` is a Borsh Vec`<u8>` (u32 length prefix + bytes)
/// - `resultsUri` is [u8; 128] (NOT a Rust String), stored as Uint8List
class ResolvedGameModel extends BorshObject {
  ResolvedGameModel({
    required this.epoch,
    required this.tier,
    required this.status,
    required this.bump,
    required this.winningNumber,
    required this.rngEpochSlotUsed,
    required this.rngBlockhashUsed,
    required this.attemptCount,
    required this.lastUpdatedSlot,
    required this.lastUpdatedTs,
    required this.carryOverBets,
    required this.totalBets,
    required this.carryInLamports,
    required this.carryOutLamports,
    required this.protocolFeeLamports,
    required this.netPrizePool,
    required this.totalWinners,
    required this.claimedWinners,
    required this.resolvedAt,
    required this.merkleRoot,
    required this.resultsUri,
    required this.claimedBitmap,
    required this.version,
    required this.claimedLamports,
    required this.firstEpochInChain,
    required this.rolloverReason,
    required this.secondaryRolloverNumber,
    required this.feeBps,
    required this.reserved,
  });

  // Identification
  final BigInt epoch; // u64
  final int tier; // u8
  final int status; // u8
  final int bump; // u8
  final int winningNumber; // u8

  // RNG provenance
  final BigInt rngEpochSlotUsed; // u64
  final Uint8List rngBlockhashUsed; // [u8; 32]

  // Processing metadata
  final int attemptCount; // u8
  final BigInt lastUpdatedSlot; // u64
  final int lastUpdatedTs; // i64

  // Accounting
  final int carryOverBets; // u32
  final int totalBets; // u32
  final BigInt carryInLamports; // u64
  final BigInt carryOutLamports; // u64
  final BigInt protocolFeeLamports; // u64
  final BigInt netPrizePool; // u64
  final int totalWinners; // u32
  final int claimedWinners; // u32
  final int resolvedAt; // i64

  // Claims
  final Uint8List merkleRoot; // [u8; 32]
  final Uint8List resultsUri; // [u8; 128]
  final Uint8List claimedBitmap; // Vec<u8>

  // Versioning / extensions
  final int version; // u8
  final BigInt claimedLamports; // u64
  final BigInt firstEpochInChain; // u64

  final int rolloverReason; // u8
  final int secondaryRolloverNumber; // u8
  final int feeBps; // u16
  final Uint8List reserved; // [u8; 12]

  // --------------------------------------------------------------------------
  // Borsh schema (MUST match Rust field order exactly)
  // --------------------------------------------------------------------------
  static BorshSchema get staticSchema => {
    // Identification
    'epoch': borsh.u64,
    'tier': borsh.u8,
    'status': borsh.u8,
    'bump': borsh.u8,
    'winningNumber': borsh.u8,

    // RNG provenance
    'rngEpochSlotUsed': borsh.u64,
    'rngBlockhashUsed': borsh.array(borsh.u8, 32),

    // Processing metadata
    'attemptCount': borsh.u8,
    'lastUpdatedSlot': borsh.u64,
    'lastUpdatedTs': borsh.i64,

    // Accounting
    'carryOverBets': borsh.u32,
    'totalBets': borsh.u32,
    'carryInLamports': borsh.u64,
    'carryOutLamports': borsh.u64,
    'protocolFeeLamports': borsh.u64,
    'netPrizePool': borsh.u64,
    'totalWinners': borsh.u32,
    'claimedWinners': borsh.u32,
    'resolvedAt': borsh.i64,

    // Claims
    'merkleRoot': borsh.array(borsh.u8, 32),
    'resultsUri': borsh.array(borsh.u8, 128),
    'claimedBitmap': borsh.vec(borsh.u8),

    // Versioning / extensions
    'version': borsh.u8,
    'claimedLamports': borsh.u64,
    'firstEpochInChain': borsh.u64,

    'rolloverReason': borsh.u8,
    'secondaryRolloverNumber': borsh.u8,
    'feeBps': borsh.u16,
    'reserved': borsh.array(borsh.u8, 12),
  };

  @override
  BorshSchema get borshSchema => staticSchema;

  // --------------------------------------------------------------------------
  // JSON
  // --------------------------------------------------------------------------
  factory ResolvedGameModel.fromJson(Map<String, dynamic> json) => ResolvedGameModel(
    epoch: json['epoch'] as BigInt,
    tier: json['tier'] as int,
    status: json['status'] as int,
    bump: json['bump'] as int,
    winningNumber: json['winningNumber'] as int,

    rngEpochSlotUsed: json['rngEpochSlotUsed'] as BigInt,
    rngBlockhashUsed: Uint8List.fromList(List<int>.from(json['rngBlockhashUsed'] as List)),

    attemptCount: json['attemptCount'] as int,
    lastUpdatedSlot: json['lastUpdatedSlot'] as BigInt,
    lastUpdatedTs: json['lastUpdatedTs'] as int,

    carryOverBets: json['carryOverBets'] as int,
    totalBets: json['totalBets'] as int,
    carryInLamports: json['carryInLamports'] as BigInt,
    carryOutLamports: json['carryOutLamports'] as BigInt,
    protocolFeeLamports: json['protocolFeeLamports'] as BigInt,
    netPrizePool: json['netPrizePool'] as BigInt,
    totalWinners: json['totalWinners'] as int,
    claimedWinners: json['claimedWinners'] as int,
    resolvedAt: json['resolvedAt'] as int,

    merkleRoot: Uint8List.fromList(List<int>.from(json['merkleRoot'] as List)),
    resultsUri: Uint8List.fromList(List<int>.from(json['resultsUri'] as List)),
    claimedBitmap: Uint8List.fromList(List<int>.from(json['claimedBitmap'] as List)),

    version: json['version'] as int,
    claimedLamports: json['claimedLamports'] as BigInt,
    firstEpochInChain: json['firstEpochInChain'] as BigInt,

    rolloverReason: json['rolloverReason'] as int,
    secondaryRolloverNumber: json['secondaryRolloverNumber'] as int,
    feeBps: json['feeBps'] as int,
    reserved: Uint8List.fromList(List<int>.from(json['reserved'] as List)),
  );

  @override
  Map<String, dynamic> toJson() => {
    'epoch': epoch,
    'tier': tier,
    'status': status,
    'bump': bump,
    'winningNumber': winningNumber,

    'rngEpochSlotUsed': rngEpochSlotUsed,
    'rngBlockhashUsed': rngBlockhashUsed.toList(),

    'attemptCount': attemptCount,
    'lastUpdatedSlot': lastUpdatedSlot,
    'lastUpdatedTs': lastUpdatedTs,

    'carryOverBets': carryOverBets,
    'totalBets': totalBets,
    'carryInLamports': carryInLamports,
    'carryOutLamports': carryOutLamports,
    'protocolFeeLamports': protocolFeeLamports,
    'netPrizePool': netPrizePool,
    'totalWinners': totalWinners,
    'claimedWinners': claimedWinners,
    'resolvedAt': resolvedAt,

    'merkleRoot': merkleRoot.toList(),
    'resultsUri': resultsUri.toList(),
    'claimedBitmap': claimedBitmap.toList(),

    'version': version,
    'claimedLamports': claimedLamports,
    'firstEpochInChain': firstEpochInChain,

    'rolloverReason': rolloverReason,
    'secondaryRolloverNumber': secondaryRolloverNumber,
    'feeBps': feeBps,
    'reserved': reserved.toList(),
  };

  // --------------------------------------------------------------------------
  // Convenience helpers
  // --------------------------------------------------------------------------

  bool get isResolved => status == 2;
  bool get isProcessing => status == 1;
  bool get isFailed => status == 0;
  bool get isRollover => rolloverReason != 0;

  // Convenience helpers
  String get rngBlockhashBase58 => base58encode(rngBlockhashUsed);

  String get resultsUriString {
    final trimmed = resultsUri.takeWhile((b) => b != 0).toList(growable: false);
    return String.fromCharCodes(trimmed);
  }

  String get rolloverReasonText {
    switch (rolloverReason) {
      case 1:
        return 'NoWinners';
      case 2:
        return 'RolloverNumber';
      case 0:
      default:
        return 'None';
    }
  }
}
