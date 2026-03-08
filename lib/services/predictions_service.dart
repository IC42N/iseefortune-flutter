import 'dart:typed_data';

import 'package:solana/base58.dart' show base58encode;
import 'package:solana/dto.dart';

import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/solana/decode/account_bytes.dart';
import 'package:iseefortune_flutter/solana/decode/decode_prediction.dart';
import 'package:iseefortune_flutter/solana/decode/extract_base64.dart';
import 'package:iseefortune_flutter/solana/service/client.dart';
import 'package:iseefortune_flutter/solana/service/websocket.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

class PredictionAccountUpdate {
  PredictionAccountUpdate({required this.pubkey, required this.prediction});
  final String pubkey;
  final PredictionModel prediction;
}

class PredictionsService {
  PredictionsService(this._ws, this._rpc);

  final SolanaWsService _ws;
  final SolanaClientService _rpc;

  static const int predictionDataSize = 129;
  static const int predictionGameEpochOffset = 8;
  static const int predictionTierOffset = 56;

  // ---------------------------------------------------------------------------
  // WS: programSubscribe filters use base58-encoded bytes (JSON RPC format)
  // ---------------------------------------------------------------------------

  Stream<PredictionAccountUpdate> subscribePredictionsForGameEpochTier({
    required String programId,
    required BigInt gameEpoch,
    required int tier,
    String commitment = 'confirmed', // opinionated: UI stability
  }) {
    final filters = _buildWsFilters(gameEpoch: gameEpoch, tier: tier);

    icLogger.i(
      '[Current Game Predictions Service] subscribe start program=$programId gameEpoch=$gameEpoch tier=$tier filters=$filters',
    );

    return _ws
        .programSubscribe(programId, encoding: 'base64', commitment: commitment, filters: filters)
        .asyncExpand<PredictionAccountUpdate>((result) async* {
          try {
            final pubkey = result['pubkey'];
            if (pubkey is! String || pubkey.isEmpty) {
              icLogger.w('[Current Game PredictionsService] WS missing pubkey. keys=${result.keys}');
              return;
            }

            final account = result['account'];
            if (account is! Map) {
              icLogger.w(
                '[Current Game PredictionsService] WS missing account for $pubkey. keys=${result.keys}',
              );
              return;
            }

            final accountMap = Map<String, dynamic>.from(account);
            final data = accountMap['data'];
            if (data == null) {
              icLogger.w(
                '[Current Game PredictionsService] WS null account.data for $pubkey (maybe closed).',
              );
              return;
            }

            final prediction = _decodePrediction(data, label: 'PredictionWS($pubkey)');
            yield PredictionAccountUpdate(pubkey: pubkey, prediction: prediction);
          } catch (e, st) {
            icLogger.w('[Current Game PredictionsService] WS decode error: $e');
            icLogger.d('$st');
            return;
          }
        });
  }

  // ---------------------------------------------------------------------------
  // RPC: getProgramAccounts filters use RAW BYTES (solana.dart API)
  // ---------------------------------------------------------------------------

  Future<List<MapEntry<String, PredictionModel>>> fetchPredictionsForGameEpochTier({
    required String programId,
    required BigInt gameEpoch,
    required int tier,
  }) async {
    final filters = <ProgramDataFilter>[
      ProgramDataFilter.dataSize(predictionDataSize),
      ProgramDataFilter.memcmp(offset: predictionGameEpochOffset, bytes: _u64LeBytes(gameEpoch)),
      ProgramDataFilter.memcmp(offset: predictionTierOffset, bytes: _u8Bytes(tier)),
    ];

    icLogger.i(
      '[Current Game PredictionsService] RPC getProgramAccounts program=$programId gameEpoch=$gameEpoch tier=$tier',
    );

    final accounts = await _rpc.rpcClient.getProgramAccounts(
      programId,
      commitment: Commitment.confirmed,
      encoding: Encoding.base64,
      filters: filters,
    );

    return accounts
        .map((a) {
          final pubkey = a.pubkey;
          final model = _decodePrediction(a.account.data, label: 'PredictionRPC($pubkey)');
          return MapEntry(pubkey, model);
        })
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // WS filter builder (base58 strings)
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _buildWsFilters({required BigInt gameEpoch, required int tier}) {
    return <Map<String, dynamic>>[
      {'dataSize': predictionDataSize},
      {
        'memcmp': {'offset': predictionGameEpochOffset, 'bytes': _u64LeBase58(gameEpoch)},
      },
      {
        'memcmp': {'offset': predictionTierOffset, 'bytes': _u8Base58(tier)},
      },
    ];
  }

  // ---------------------------------------------------------------------------
  // Encoding helpers
  // ---------------------------------------------------------------------------

  // WS wants base58-encoded bytes:
  static String _u8Base58(int v) => base58encode(Uint8List.fromList([v & 0xFF]));

  static String _u64LeBase58(BigInt v) => base58encode(_u64LeBytes(v));

  // RPC wants raw bytes:
  static Uint8List _u8Bytes(int v) => Uint8List.fromList([v & 0xFF]);

  static Uint8List _u64LeBytes(BigInt v) {
    final out = Uint8List(8);
    var x = v;
    for (var i = 0; i < 8; i++) {
      out[i] = (x & BigInt.from(0xFF)).toInt();
      x >>= 8;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Decode helper (handles WS + RPC account.data shapes)
  // ---------------------------------------------------------------------------

  static PredictionModel _decodePrediction(dynamic data, {required String label}) {
    final base64Str = extractBase64FromAccountData(data, label: label);
    final bytes = accountBytesFromBase64(base64Str);

    if (bytes.length != predictionDataSize) {
      icLogger.w('[$label] unexpected data size: ${bytes.length} (expected $predictionDataSize)');
    }

    return decodePredictionFromAccountBytes(bytes);
  }
}
