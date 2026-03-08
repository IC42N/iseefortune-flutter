// lib/solana/app_pdas.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:iseefortune_flutter/constants/program_id.dart';
import 'package:solana/solana.dart';

/// Central place for *all* PDAs in IC42N.
///
/// Keep this file pure:
/// - no RPC calls
/// - no provider state
/// - no caching
///
/// Just: inputs -> addresses.
class AppPdas {
  AppPdas._();

  // ---------------------------------------------------------------------------
  // LiveFeed
  // Anchor seeds: [b"live_feed", &[tier]]
  // ---------------------------------------------------------------------------
  static Future<String> liveFeedPda(int tier) async {
    final t = _u8Tier(tier);

    final seeds = <List<int>>[
      utf8.encode('live_feed'),
      [t], // &[tier]
    ];

    final pda = await Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: programPubkey);

    return pda.toBase58();
  }

  // ---------------------------------------------------------------------------
  // Config (example)
  // Replace 'config' seed with your real Config seed prefix
  // ---------------------------------------------------------------------------
  static Future<String> configPda() async {
    final seeds = <List<int>>[utf8.encode('config')];

    final pda = await Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: programPubkey);

    return pda.toBase58();
  }

  // ---------------------------------------------------------------------------
  // PlayerProfile
  // Anchor seeds: [b"profile", player.key().as_ref()]
  // ---------------------------------------------------------------------------
  static Future<String> playerProfilePda(String playerPubkeyBase58) async {
    final player = Ed25519HDPublicKey.fromBase58(playerPubkeyBase58);

    final seeds = <List<int>>[utf8.encode('profile'), player.bytes];

    final pda = await Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: programPubkey);

    return pda.toBase58();
  }

  // ---------------------------------------------------------------------------
  // Bet
  // Anchor seeds:
  //   [b"bet", player.key().as_ref(), live_feed.first_epoch_in_chain.to_le_bytes(), &[tier]]
  //
  // NOTE: firstEpochInChain is assumed u64 (8 bytes LE), matching to_le_bytes()
  // ---------------------------------------------------------------------------
  static Future<String> betPda({
    required String playerPubkeyBase58,
    required int firstEpochInChain, // u64 on chain
    required int tier, // u8 on chain
  }) async {
    final player = Ed25519HDPublicKey.fromBase58(playerPubkeyBase58);
    final t = _u8Tier(tier);

    final seeds = <List<int>>[
      utf8.encode('bet'),
      player.bytes,
      _u64le(firstEpochInChain),
      [t],
    ];

    final pda = await Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: programPubkey);

    return pda.toBase58();
  }

  // ---------------------------------------------------------------------------
  // ResolvedGame
  // Anchor seeds: [b"resolved_game", epoch.to_le_bytes().as_ref(), &[tier]]
  //
  // NOTE: epoch is assumed u64 (8 bytes LE), matching to_le_bytes()
  // ---------------------------------------------------------------------------
  static Future<String> resolvedGamePda({
    required int epoch, // u64 on chain
    required int tier, // u8 on chain
  }) async {
    final t = _u8Tier(tier);

    final seeds = <List<int>>[
      utf8.encode('resolved_game'),
      _u64le(epoch),
      [t],
    ];

    final pda = await Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: programPubkey);

    return pda.toBase58();
  }

  static Future<Ed25519HDPublicKey> resolvedGamePdaPubkey({
    required int epoch, // u64 on chain
    required int tier, // u8 on chain
  }) async {
    final t = _u8Tier(tier);

    final seeds = <List<int>>[
      utf8.encode('resolved_game'),
      _u64le(epoch),
      [t],
    ];

    return await Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: programPubkey);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Enforce tier fits Anchor's &[tier] seed (u8).
  static int _u8Tier(int tier) {
    final t = tier < 1 ? 1 : tier;
    if (t > 255) throw ArgumentError('tier must be u8 (1..255). Got $t');
    return t;
  }

  /// u64 little-endian (Anchor's to_le_bytes() for u64).
  static List<int> _u64le(int v) {
    if (v < 0) throw ArgumentError('u64 cannot be negative: $v');

    // Dart int is unbounded, but ByteData wants 0..2^64-1.
    final bd = ByteData(8);
    bd.setUint64(0, v, Endian.little);
    return bd.buffer.asUint8List();
  }
}
