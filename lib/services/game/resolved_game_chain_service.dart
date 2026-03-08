import 'package:iseefortune_flutter/models/game/game_pda_model.dart';
import 'package:iseefortune_flutter/solana/decode/account_bytes.dart';
import 'package:iseefortune_flutter/solana/decode/decode_game.dart';
import 'package:iseefortune_flutter/solana/decode/extract_base64.dart';
import 'package:iseefortune_flutter/solana/pdas.dart';
import 'package:iseefortune_flutter/solana/service/websocket.dart';
import 'package:iseefortune_flutter/utils/solana/json_rpc.dart';

/// ResolvedGameService
/// ---------------------------------------------------------------------------
/// Stateless service for ResolvedGame PDA snapshots (and optional subscriptions).
///
/// Responsibilities:
/// - derive ResolvedGame PDA for (epoch,tier)
/// - fetch raw account data via JSON-RPC (getAccountInfo)
/// - decode into ResolvedGameModel
/// - optionally subscribe via WebSocket (accountSubscribe)
///
/// Non-responsibilities:
/// - no disk caching
/// - no UI state
class ResolvedGameService {
  ResolvedGameService(this._ws);

  final SolanaWsService _ws;

  /// Optional in-memory cache of derived PDAs by key "epoch:tier".
  ///
  /// Why cache:
  /// - derivation is deterministic
  /// - avoids recomputing seeds repeatedly when the user taps history
  final Map<String, String> _cachedResolvedPdas = {};

  String _key(int epoch, int tier) => '$epoch:$tier';

  // ---------------------------------------------------------------------------
  // PDA helpers
  // ---------------------------------------------------------------------------

  /// Returns the ResolvedGame PDA (base58 string), computed once per (epoch,tier).
  Future<String> _resolvedGamePda({required int epoch, required int tier}) async {
    final k = _key(epoch, tier);
    final existing = _cachedResolvedPdas[k];
    if (existing != null) return existing;

    // Adjust to your actual PDA helper signature.
    // If your PDA wants u64, pass BigInt.from(epoch).
    final derived = await AppPdas.resolvedGamePda(epoch: epoch, tier: tier);

    _cachedResolvedPdas[k] = derived;
    return derived;
  }

  // ---------------------------------------------------------------------------
  // Snapshot fetch (HTTP)
  // ---------------------------------------------------------------------------

  /// Fetch + decode ResolvedGame for (epoch,tier).
  ///
  /// Commitment:
  /// - `finalized` is safest for resolved history
  /// - `confirmed` is usually fine
  Future<ResolvedGameModel> fetchResolvedGame({
    required int epoch,
    required int tier,
    String commitment = 'finalized',
  }) async {
    final pubkey = await _resolvedGamePda(epoch: epoch, tier: tier);
    return fetchResolvedGameByPubkey(pubkey, commitment: commitment);
  }

  /// Fetch + decode by explicit pubkey (debugging/tests).
  Future<ResolvedGameModel> fetchResolvedGameByPubkey(
    String pubkey, {
    String commitment = 'finalized',
  }) async {
    final base64Str = await fetchAccountBase64(pubkey, commitment: commitment);

    // base64 -> raw bytes (includes 8-byte discriminator)
    final bytes = accountBytesFromBase64(base64Str);

    return decodeResolvedGame(bytes);
  }

  /// Low-level RPC fetch for account data (base64 payload).
  Future<String> fetchAccountBase64(String pubkey, {String commitment = 'finalized'}) async {
    final result = await JsonRpcRaw.call(
      'getAccountInfo',
      params: [
        pubkey,
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    final value = result?['value'];
    if (value == null) {
      throw Exception('ResolvedGame account not found: $pubkey');
    }

    final data = value['data'];
    return extractBase64FromAccountData(data, label: 'ResolvedGame($pubkey)');
  }

  // ---------------------------------------------------------------------------
  // WebSocket subscription (optional)
  // ---------------------------------------------------------------------------

  /// Subscribe to updates for a specific (epoch,tier) ResolvedGame PDA.
  ///
  /// For history you may not need this, but it's handy for "just resolved"
  /// screens or when you're watching the current epoch flip to resolved.
  Future<Stream<ResolvedGameModel>> subscribeResolvedGame({
    required int epoch,
    required int tier,
    String commitment = 'confirmed',
  }) async {
    final pubkey = await _resolvedGamePda(epoch: epoch, tier: tier);

    return _ws
        .accountSubscribe(pubkey, encoding: 'base64', commitment: commitment)
        .where((value) => value != null)
        .map((value) {
          final data = value!['data'];
          final base64Str = extractBase64FromAccountData(data, label: 'ResolvedGameWS($pubkey)');
          final bytes = accountBytesFromBase64(base64Str);
          return decodeResolvedGame(bytes);
        });
  }

  /// Subscribe to updates for an explicit ResolvedGame PDA pubkey.
  ///
  /// Use this for the live "epoch end" modal where you already know the PDA.
  Future<Stream<ResolvedGameModel>> subscribeResolvedGameByPubkey(
    String pubkey, {
    String commitment = 'confirmed',
  }) async {
    return _ws
        .accountSubscribe(pubkey, encoding: 'base64', commitment: commitment)
        .where((value) => value != null)
        .map((value) {
          final data = value!['data'];
          final base64Str = extractBase64FromAccountData(data, label: 'ResolvedGameWS($pubkey)');
          final bytes = accountBytesFromBase64(base64Str);
          return decodeResolvedGame(bytes);
        });
  }
}
