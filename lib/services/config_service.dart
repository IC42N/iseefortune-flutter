// lib/services/config_service.dart
import 'package:iseefortune_flutter/models/config_model.dart';
import 'package:iseefortune_flutter/solana/decode/account_bytes.dart';
import 'package:iseefortune_flutter/solana/decode/decode_config.dart';
import 'package:iseefortune_flutter/solana/decode/extract_base64.dart';
import 'package:iseefortune_flutter/solana/pdas.dart';
import 'package:iseefortune_flutter/solana/service/websocket.dart';
import 'package:iseefortune_flutter/utils/solana/json_rpc.dart';

/// ConfigService
/// ---------------------------------------------------------------------------
/// Stateless service for the global Config PDA.
///
/// Responsibilities:
/// - derive Config PDA (once, cached in-memory)
/// - fetch raw account data via JSON-RPC (getAccountInfo)
/// - decode into ConfigModel
/// - optionally subscribe via WebSocket (accountSubscribe)
///
/// Non-responsibilities:
/// - no disk caching (SharedPreferences)
/// - no UI state (providers handle that)
class ConfigService {
  ConfigService(this._ws);

  final SolanaWsService _ws;

  /// In-memory cached Config PDA (base58 string).
  ///
  /// Why cache:
  /// - Config PDA is deterministic & static
  /// - avoids repeating an `await` for every fetch/subscribe call
  String? _cachedConfigPda;

  // ---------------------------------------------------------------------------
  // PDA helpers
  // ---------------------------------------------------------------------------

  /// Returns the Config PDA, computed once and cached in memory.
  Future<String> _configPda() async {
    final existing = _cachedConfigPda;
    if (existing != null) return existing;

    final derived = await AppPdas.configPda();
    _cachedConfigPda = derived;
    return derived;
  }

  // ---------------------------------------------------------------------------
  // Snapshot fetch (HTTP)
  // ---------------------------------------------------------------------------

  /// Fetch + decode the global config account.
  ///
  /// Defaults to `confirmed` because Config changes are rare/admin-driven.
  /// If you want fastest UI reflection for admin flips, use `processed`.
  Future<ConfigModel> fetchConfig({String commitment = 'processed'}) async {
    final pubkey = await _configPda();
    return fetchConfigByPubkey(pubkey, commitment: commitment);
  }

  /// Fetch + decode by explicit pubkey (debugging / tests).
  Future<ConfigModel> fetchConfigByPubkey(String pubkey, {String commitment = 'processed'}) async {
    final base64Str = await fetchAccountBase64(pubkey, commitment: commitment);

    // base64 -> raw bytes (includes 8-byte discriminator)
    final bytes = accountBytesFromBase64(base64Str);

    // decoder should handle stripping internally (if it already does)
    return decodeConfigFromAccountBytes(bytes);
  }

  /// Low-level RPC fetch for account data.
  ///
  /// Returns:
  /// - raw base64 payload
  ///
  /// Important:
  /// - some wrappers return `data` as ["<b64>", "base64"]
  /// - others normalize to `<b64>`
  /// We support both via extractBase64FromAccountData().
  Future<String> fetchAccountBase64(String pubkey, {String commitment = 'processed'}) async {
    final result = await JsonRpcRaw.call(
      'getAccountInfo',
      params: [
        pubkey,
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    final value = result?['value'];
    if (value == null) {
      throw Exception('Config account not found: $pubkey');
    }

    final data = value['data'];
    return extractBase64FromAccountData(data, label: 'Config($pubkey)');
  }

  // ---------------------------------------------------------------------------
  // WebSocket subscription (live updates)
  // ---------------------------------------------------------------------------

  /// Subscribe to config updates.
  ///
  /// Emits:
  /// - decoded ConfigModel snapshots whenever the account changes
  ///
  /// Notes:
  /// - Config updates are rare, but useful so the UI instantly reflects:
  ///   - tier activation flips
  ///   - pause flags
  ///   - fee changes
  ///
  /// Commitment:
  /// - `confirmed` is safe
  /// - `processed` is faster (UI updates sooner)
  Future<Stream<ConfigModel>> subscribeConfig({String commitment = 'confirmed'}) async {
    final pubkey = await _configPda();

    return _ws
        .accountSubscribe(pubkey, encoding: 'base64', commitment: commitment)
        .where((value) => value != null)
        .map((value) {
          final data = value!['data'];
          final base64Str = extractBase64FromAccountData(data, label: 'ConfigWS($pubkey)');
          final bytes = accountBytesFromBase64(base64Str);
          return decodeConfigFromAccountBytes(bytes);
        });
  }
}
