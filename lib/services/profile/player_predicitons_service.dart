import 'dart:convert';
import 'dart:typed_data';

import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/solana/decode/decode_prediction.dart';
import 'package:iseefortune_flutter/solana/service/websocket.dart';
import 'package:iseefortune_flutter/utils/solana/get_multiple_accounts_chunked.dart';

class PlayerPredictionsService {
  PlayerPredictionsService(this.ws);

  final SolanaWsService ws;

  // ----------------------------
  // Fetch (chunked for UI)
  // ----------------------------

  Future<void> fetchPredictionsChunkedEach(
    List<String> pubkeys, {
    int chunkSize = 20,
    String commitment = 'confirmed',
    String? tag,
    required void Function(Map<String, PredictionModel> chunkModels) onChunk,
  }) async {
    final keys = _dedupePreserveOrder(pubkeys);

    await getMultipleAccountsChunkedEach(
      keys,
      chunkSize: chunkSize,
      commitment: commitment,
      tag: tag ?? 'playerPredictions',
      onChunk: (chunkAccounts) async {
        final models = <String, PredictionModel>{};
        for (final acc in chunkAccounts) {
          try {
            final bytes = Uint8List.fromList(base64Decode(acc.dataBase64));
            models[acc.pubkey] = decodePredictionFromAccountBytes(bytes);
          } catch (_) {
            // ignore per-account decode errors
          }
        }

        onChunk(models);
      },
    );
  }

  // ----------------------------
  // Fetch (one-shot map)
  // ----------------------------

  Future<Map<String, PredictionModel>> fetchPredictionsMap(
    List<String> pubkeys, {
    int chunkSize = 20,
    String commitment = 'confirmed',
    String? tag,
  }) async {
    final keys = _dedupePreserveOrder(pubkeys);

    final accounts = await getMultipleAccountsChunked(
      keys,
      chunkSize: chunkSize,
      commitment: commitment,
      tag: tag ?? 'playerPredictions',
    );

    final out = <String, PredictionModel>{};

    for (final acc in accounts) {
      try {
        final bytes = Uint8List.fromList(base64Decode(acc.dataBase64));
        final model = decodePredictionFromAccountBytes(bytes);
        out[acc.pubkey] = model;
      } catch (_) {}
    }

    return out;
  }

  // ----------------------------
  // Mutable selection
  // ----------------------------

  /// Only subscribe to predictions that can still change.
  ///
  /// In a multi-epoch game chain, the stable "game id" is gameEpoch
  /// (the first epoch in chain). This remains constant while the chain spans
  /// across epochs. So we treat "belongs to current game" as:
  ///   p.gameEpoch == liveFeed.first_epoch_in_chain
  ///
  /// Additionally, we keep unclaimed predictions live so claim status can flip.
  List<String> pickMutableKeysForActiveGame(
    Map<String, PredictionModel> byPubkey, {
    required BigInt activeGameEpoch,
  }) {
    final out = <String>[];

    for (final e in byPubkey.entries) {
      final p = e.value;

      final isInActiveGame = p.gameEpoch == activeGameEpoch;
      final isUnclaimed = !p.isClaimed;

      if (isInActiveGame || isUnclaimed) out.add(e.key);
    }

    return out;
  }

  // ----------------------------
  // Subscription (1 prediction)
  // ----------------------------

  Stream<PredictionModel> subscribePrediction(String pubkey, {String commitment = 'confirmed'}) {
    return ws
        .accountSubscribe(pubkey, commitment: commitment, encoding: 'base64')
        // accountSubscribe emits Map<String,dynamic>? and drops null values already, but be safe:
        .where((v) => v != null)
        .cast<Map<String, dynamic>>()
        .map((value) {
          // value["data"] is typically ["<base64>", "base64"]
          final data = value['data'];
          if (data is List && data.isNotEmpty && data.first is String) {
            final b64 = data.first as String;
            final bytes = Uint8List.fromList(base64Decode(b64));
            return decodePredictionFromAccountBytes(bytes);
          }

          // Some RPCs can return data as String (rare), handle anyway:
          if (data is String) {
            final bytes = Uint8List.fromList(base64Decode(data));
            return decodePredictionFromAccountBytes(bytes);
          }

          throw StateError('Unexpected accountSubscribe data shape for $pubkey: ${value['data']}');
        });
  }

  // ----------------------------
  // Helpers
  // ----------------------------

  List<String> _dedupePreserveOrder(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final x in input) {
      if (x.isEmpty) continue;
      if (seen.add(x)) out.add(x);
    }
    return out;
  }
}
