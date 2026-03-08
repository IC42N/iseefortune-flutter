// lib/services/live_feed_service.dart

import 'dart:typed_data';
import 'package:iseefortune_flutter/utils/logger.dart'; // <-- add

import 'package:iseefortune_flutter/solana/decode/extract_base64.dart';
import 'package:iseefortune_flutter/solana/pdas.dart';
import 'package:iseefortune_flutter/utils/solana/json_rpc.dart';
import 'package:iseefortune_flutter/solana/service/websocket.dart';

import 'package:iseefortune_flutter/solana/decode/account_bytes.dart';
import 'package:iseefortune_flutter/solana/decode/decode_live_feed.dart';
import 'package:iseefortune_flutter/models/live_feed_model.dart';

class LiveFeedService {
  LiveFeedService(this._ws);

  final SolanaWsService _ws;

  Future<LiveFeedModel> fetchLiveFeed(int tier, {String commitment = 'confirmed'}) async {
    final pubkey = await AppPdas.liveFeedPda(tier);
    return fetchLiveFeedByPubkey(pubkey, commitment: commitment);
  }

  Future<LiveFeedModel> fetchLiveFeedByPubkey(String pubkey, {String commitment = 'confirmed'}) async {
    final base64Str = await fetchAccountBase64(pubkey, commitment: commitment);

    // Debug: base64 + raw lengths
    icLogger.d('[LiveFeedService] HTTP pubkey=$pubkey b64Len=${base64Str.length}');

    final Uint8List bytes = accountBytesFromBase64(base64Str);

    // Debug: raw bytes + body preview (after discriminator)
    icLogger.d(
      '[LiveFeedService] HTTP rawLen=${bytes.length} bodyLen=${bytes.length >= 8 ? (bytes.length - 8) : -1}',
    );
    if (bytes.length >= 16) {
      final bodyPreview = bytes.sublist(8, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      icLogger.d('[LiveFeedService] HTTP body[0..8)= $bodyPreview');
    } else {
      icLogger.w('[LiveFeedService] HTTP bytes too short to preview: len=${bytes.length}');
    }

    return decodeLiveFeedFromAccountBytes(bytes);
  }

  Stream<LiveFeedModel> subscribeLiveFeed(int tier, {String commitment = 'processed'}) async* {
    final pubkey = await AppPdas.liveFeedPda(tier);

    yield* _ws
        .accountSubscribe(pubkey, encoding: 'base64', commitment: commitment)
        .where((value) => value != null)
        .map((value) {
          final data = value!['data'];
          final base64Str = extractBase64FromAccountData(data, label: 'LiveFeedWS($pubkey)');

          icLogger.d('[LiveFeedService] WS pubkey=$pubkey b64Len=${base64Str.length}');

          final Uint8List bytes = accountBytesFromBase64(base64Str);

          icLogger.d(
            '[LiveFeedService] WS rawLen=${bytes.length} bodyLen=${bytes.length >= 8 ? (bytes.length - 8) : -1}',
          );
          if (bytes.length >= 16) {
            final bodyPreview = bytes
                .sublist(8, 16)
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(' ');
            icLogger.d('[LiveFeedService] WS body[0..8)= $bodyPreview');
          }

          return decodeLiveFeedFromAccountBytes(bytes);
        });
  }

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
      throw Exception('LiveFeed account not found: $pubkey');
    }

    final data = value['data'];
    return extractBase64FromAccountData(data, label: 'LiveFeed($pubkey)');
  }
}
