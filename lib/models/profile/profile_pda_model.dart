import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:solana_borsh/models.dart';
import 'package:solana_borsh/types.dart';

/// Mirrors Rust PlayerProfile account (AFTER the 8-byte Anchor discriminator).
///
/// Rust:
/// - player: Pubkey
/// - bump: u8
/// - tickets_available: u32
/// - total_bets: u64
/// - total_lamports_wagered: u64
/// - last_played_epoch: u64
/// - last_played_tier: u8
/// - last_played_timestamp: i64
/// - xp_points: u32
/// - recent_bets: [Pubkey; 40]
/// - recent_bets_len: u16
/// - recent_bets_head: u16
/// - locked_until_epoch: u64
/// - first_played_epoch: u64
/// - _reserved: [u8; 16]
class PlayerProfilePDAModel extends BorshObject {
  static const int recentBetsCap = 40;

  PlayerProfilePDAModel({
    required this.player,
    required this.bump,
    required this.ticketsAvailable,
    required this.totalBets,
    required this.totalLamportsWagered,
    required this.lastPlayedEpoch,
    required this.lastPlayedTier,
    required this.lastPlayedTimestamp,
    required this.xpPoints,
    required this.recentBets,
    required this.recentBetsLen,
    required this.recentBetsHead,
    required this.lockedUntilEpoch,
    required this.firstPlayedEpoch,
    required this.reserved,
  });

  /// Pubkey base58 string
  final String player;

  final int bump; // u8
  final int ticketsAvailable; // u32

  final BigInt totalBets; // u64
  final BigInt totalLamportsWagered; // u64
  final BigInt lastPlayedEpoch; // u64
  final int lastPlayedTier; // u8
  final int lastPlayedTimestamp; // i64 (Dart int)
  final int xpPoints; // u32

  /// [Pubkey; 40]
  final List<String> recentBets;

  final int recentBetsLen; // u16
  final int recentBetsHead; // u16

  final BigInt lockedUntilEpoch; // u64
  final BigInt firstPlayedEpoch; // u64

  final Uint8List reserved; // [u8; 16]

  // ----- schema -----

  static final _pubkeyArray40 = borsh.array(borsh.pubkey, recentBetsCap);

  static BorshSchema get staticSchema => {
    'player': borsh.pubkey,
    'bump': borsh.u8,
    'ticketsAvailable': borsh.u32,
    'totalBets': borsh.u64,
    'totalLamportsWagered': borsh.u64,
    'lastPlayedEpoch': borsh.u64,
    'lastPlayedTier': borsh.u8,
    'lastPlayedTimestamp': borsh.i64,
    'xpPoints': borsh.u32,
    'recentBets': _pubkeyArray40, // ✅ [Pubkey; 40]
    'recentBetsLen': borsh.u16,
    'recentBetsHead': borsh.u16,
    'lockedUntilEpoch': borsh.u64,
    'firstPlayedEpoch': borsh.u64,
    'reserved': borsh.array(borsh.u8, 16),
  };

  @override
  BorshSchema get borshSchema => staticSchema;

  factory PlayerProfilePDAModel.fromJson(Map<String, dynamic> json) => PlayerProfilePDAModel(
    player: json['player'] as String,
    bump: json['bump'] as int,
    ticketsAvailable: json['ticketsAvailable'] as int,
    totalBets: json['totalBets'] as BigInt,
    totalLamportsWagered: json['totalLamportsWagered'] as BigInt,
    lastPlayedEpoch: json['lastPlayedEpoch'] as BigInt,
    lastPlayedTier: json['lastPlayedTier'] as int,
    lastPlayedTimestamp: json['lastPlayedTimestamp'] as int,
    xpPoints: json['xpPoints'] as int,
    recentBets: (json['recentBets'] as List).cast<String>(),
    recentBetsLen: json['recentBetsLen'] as int,
    recentBetsHead: json['recentBetsHead'] as int,
    lockedUntilEpoch: json['lockedUntilEpoch'] as BigInt,
    firstPlayedEpoch: json['firstPlayedEpoch'] as BigInt,
    reserved: json['reserved'] is Uint8List
        ? (json['reserved'] as Uint8List)
        : Uint8List.fromList(List<int>.from(json['reserved'] as List)),
  );

  @override
  Map<String, dynamic> toJson() => {
    'player': player,
    'bump': bump,
    'ticketsAvailable': ticketsAvailable,
    'totalBets': totalBets,
    'totalLamportsWagered': totalLamportsWagered,
    'lastPlayedEpoch': lastPlayedEpoch,
    'lastPlayedTier': lastPlayedTier,
    'lastPlayedTimestamp': lastPlayedTimestamp,
    'xpPoints': xpPoints,
    'recentBets': recentBets,
    'recentBetsLen': recentBetsLen,
    'recentBetsHead': recentBetsHead,
    'lockedUntilEpoch': lockedUntilEpoch,
    'firstPlayedEpoch': firstPlayedEpoch,
    'reserved': reserved.toList(),
  };

  // ----- convenience helpers (UI-friendly) -----

  bool get isLocked => lockedUntilEpoch > BigInt.zero;

  /// Returns the valid recent bets in most-recent-first order.
  /// Uses ring buffer head/len to avoid showing garbage entries.
  List<String> get recentBetsMostRecentFirst {
    final len = recentBetsLen.clamp(0, recentBetsCap);
    if (len == 0) return const [];

    // head points to NEXT write position, so most recent is head-1
    final out = <String>[];
    var idx = (recentBetsHead - 1) % recentBetsCap;
    if (idx < 0) idx += recentBetsCap;

    for (var i = 0; i < len; i++) {
      out.add(recentBets[idx]);
      idx = (idx - 1) % recentBetsCap;
      if (idx < 0) idx += recentBetsCap;
    }
    return out;
  }
}
