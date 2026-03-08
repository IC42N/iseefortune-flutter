// lib/services/boot_snapshot_service.dart
import 'dart:typed_data';

import 'package:iseefortune_flutter/solana/pdas.dart';
import 'package:iseefortune_flutter/utils/solana/json_rpc.dart';
import 'package:iseefortune_flutter/solana/decode/account_bytes.dart';

import 'package:iseefortune_flutter/solana/decode/decode_config.dart';
import 'package:iseefortune_flutter/solana/decode/decode_live_feed.dart';

import 'package:iseefortune_flutter/models/config_model.dart';
import 'package:iseefortune_flutter/models/live_feed_model.dart';

/// Bundle of "boot critical" on-chain state.
class BootSnapshot {
  BootSnapshot({required this.config, required this.liveFeed, required this.liveFeedTier});

  final ConfigModel config;
  final LiveFeedModel liveFeed;
  final int liveFeedTier;
}

/// BootSnapshotService
/// ---------------------------------------------------------------------------
/// Fetches multiple accounts in **one RPC call** (boot-time only).
///
/// Why:
/// - reduces HTTP round-trips during startup
/// - gives you a single "all required state is present" moment
///
/// Note:
/// Providers should still subscribe via WS for live updates after boot.
class BootSnapshotService {
  /// Fetch Config + LiveFeed (for [tier]) in one `getMultipleAccounts` call.
  Future<BootSnapshot> fetchInitial({required int tier, String commitment = 'processed'}) async {
    // 1) Derive both PDAs (async today, fine)
    final configPda = await AppPdas.configPda();
    final liveFeedPda = await AppPdas.liveFeedPda(tier);

    // 2) One RPC call for both accounts
    final result = await JsonRpcRaw.call(
      'getMultipleAccounts',
      params: [
        [configPda, liveFeedPda],
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    // Solana shape: { context: {...}, value: [AccountInfo?, AccountInfo?] }
    final values = result?['value'];
    if (values is! List || values.length != 2) {
      throw StateError('getMultipleAccounts returned unexpected shape (value len != 2)');
    }

    // 3) Extract and decode
    final configBytes = _extractAccountBytes(values[0], label: 'Config', pubkey: configPda);
    final liveFeedBytes = _extractAccountBytes(values[1], label: 'LiveFeed', pubkey: liveFeedPda);

    final config = decodeConfigFromAccountBytes(configBytes);
    final liveFeed = decodeLiveFeedFromAccountBytes(liveFeedBytes);

    return BootSnapshot(config: config, liveFeed: liveFeed, liveFeedTier: tier);
  }

  /// `values[i]` is either:
  /// - null (account missing/closed)
  /// - Map with `data: ["<base64>", "base64"]`
  Uint8List _extractAccountBytes(dynamic value, {required String label, required String pubkey}) {
    if (value == null) {
      throw Exception('$label account not found: $pubkey');
    }

    if (value is! Map) {
      throw StateError('$label returned non-map value: $pubkey');
    }

    final dataArr = value['data'];
    if (dataArr is! List || dataArr.isEmpty || dataArr[0] is! String) {
      throw StateError('$label malformed data field: $pubkey');
    }

    final base64Str = dataArr[0] as String;

    // IMPORTANT:
    // This helper should output the bytes your decode_* expects:
    // - either (a) full account bytes incl discriminator,
    // - or (b) discriminator already stripped.
    //
    // Your decode helpers should match this behavior.
    return accountBytesFromBase64(base64Str);
  }
}
