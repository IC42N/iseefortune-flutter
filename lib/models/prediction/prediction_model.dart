import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:solana_borsh/models.dart';
import 'package:solana_borsh/types.dart';

/// Mirrors Rust Prediction account (AFTER 8-byte Anchor discriminator).
class PredictionModel extends BorshObject {
  PredictionModel({
    required this.gameEpoch,
    required this.epoch,
    required this.player,
    required this.tier,
    required this.predictionType,
    required this.selectionCount,
    required this.selectionsMask,
    required this.selections,
    required this.lamports,
    required this.changedCount,
    required this.placedSlot,
    required this.placedAtTs,
    required this.lastUpdatedAtTs,
    required this.hasClaimed,
    required this.claimedAtTs,
    required this.bump,
    required this.version,
    required this.lamportsPerNumber,
    required this.reserved,
  });

  /// Stable game identifier
  final BigInt gameEpoch; // u64

  /// Epoch prediction belongs to
  final BigInt epoch; // u64

  /// Player wallet (base58)
  final String player; // Pubkey

  /// Tier
  final int tier; // u8

  /// Prediction type
  /// 0 = single_number
  /// 1 = split
  /// 2 = high_low
  /// 3 = even_odd
  final int predictionType; // u8

  /// Number of active selections (1..=8)
  final int selectionCount; // u8

  /// Bitmask of selected numbers
  final int selectionsMask; // u16

  /// Exact selections used (length = 8)
  final Uint8List selections; // [u8; 8]

  /// Total lamports wagered
  final BigInt lamports; // u64

  /// Number of times prediction changed
  final int changedCount; // u8

  /// Slot when first placed
  final BigInt placedSlot; // u64

  /// Timestamp when first placed
  final int placedAtTs; // i64

  /// Timestamp of last update
  final int lastUpdatedAtTs; // i64

  /// Whether claimed (0 / 1)
  final int hasClaimed; // u8

  /// Timestamp when claimed
  final int claimedAtTs; // i64

  /// PDA bump
  final int bump; // u8

  /// Account version (expect = 1)
  final int version; // u8

  /// Lamports per selected number
  final BigInt lamportsPerNumber; // u64

  /// Reserved for future use
  final Uint8List reserved; // [u8; 8]

  // --------------------------------------------------------------------------
  // Borsh
  // --------------------------------------------------------------------------

  static BorshSchema get staticSchema => {
    'gameEpoch': borsh.u64,
    'epoch': borsh.u64,
    'player': borsh.pubkey,
    'tier': borsh.u8,
    'predictionType': borsh.u8,
    'selectionCount': borsh.u8,
    'selectionsMask': borsh.u16,
    'selections': borsh.array(borsh.u8, 8),
    'lamports': borsh.u64,
    'changedCount': borsh.u8,
    'placedSlot': borsh.u64,
    'placedAtTs': borsh.i64,
    'lastUpdatedAtTs': borsh.i64,
    'hasClaimed': borsh.u8,
    'claimedAtTs': borsh.i64,
    'bump': borsh.u8,
    'version': borsh.u8,
    'lamportsPerNumber': borsh.u64,
    'reserved': borsh.array(borsh.u8, 8),
  };

  @override
  BorshSchema get borshSchema => staticSchema;

  // --------------------------------------------------------------------------
  // JSON
  // --------------------------------------------------------------------------

  factory PredictionModel.fromJson(Map<String, dynamic> json) => PredictionModel(
    gameEpoch: json['gameEpoch'] as BigInt,
    epoch: json['epoch'] as BigInt,
    player: json['player'] as String,
    tier: json['tier'] as int,
    predictionType: json['predictionType'] as int,
    selectionCount: json['selectionCount'] as int,
    selectionsMask: json['selectionsMask'] as int,
    selections: Uint8List.fromList(List<int>.from(json['selections'] as List)),
    lamports: json['lamports'] as BigInt,
    changedCount: json['changedCount'] as int,
    placedSlot: json['placedSlot'] as BigInt,
    placedAtTs: json['placedAtTs'] as int,
    lastUpdatedAtTs: json['lastUpdatedAtTs'] as int,
    hasClaimed: json['hasClaimed'] as int,
    claimedAtTs: json['claimedAtTs'] as int,
    bump: json['bump'] as int,
    version: json['version'] as int,
    lamportsPerNumber: json['lamportsPerNumber'] as BigInt,
    reserved: Uint8List.fromList(List<int>.from(json['reserved'] as List)),
  );

  @override
  Map<String, dynamic> toJson() => {
    'gameEpoch': gameEpoch,
    'epoch': epoch,
    'player': player,
    'tier': tier,
    'predictionType': predictionType,
    'selectionCount': selectionCount,
    'selectionsMask': selectionsMask,
    'selections': selections.toList(),
    'lamports': lamports,
    'changedCount': changedCount,
    'placedSlot': placedSlot,
    'placedAtTs': placedAtTs,
    'lastUpdatedAtTs': lastUpdatedAtTs,
    'hasClaimed': hasClaimed,
    'claimedAtTs': claimedAtTs,
    'bump': bump,
    'version': version,
    'lamportsPerNumber': lamportsPerNumber,
    'reserved': reserved.toList(),
  };

  // --------------------------------------------------------------------------
  // Convenience helpers
  // --------------------------------------------------------------------------

  bool get isClaimed => hasClaimed != 0;

  /// Active selections only (trimmed to selectionCount)
  List<int> get activeSelections => selections.take(selectionCount).where((n) => n != 0).toList();

  /// Useful for UI sorting
  int get lastActivityTs => lastUpdatedAtTs != 0 ? lastUpdatedAtTs : placedAtTs;

  /// Safety check for migrations
  bool get isVersionSupported => version == 1;
}

extension PredictionWinCheck on PredictionModel {
  bool coversNumber(int n) {
    final mask = selectionsMask;
    if (n < 1 || n > 9) return false;
    final bit = 1 << n;
    return (mask & bit) == bit;
  }
}
