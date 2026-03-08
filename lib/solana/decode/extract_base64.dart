// lib/solana/decode/extract_base64.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:solana/dto.dart';

String extractBase64FromAccountData(dynamic data, {required String label}) {
  // ---------------------------------------------------------------------------
  // RPC DTO: BinaryAccountData
  // ---------------------------------------------------------------------------
  if (data is BinaryAccountData) {
    final inner = data.data; // can be List<dynamic> OR Uint8List depending on RPC impl
    //icLogger.d('[$label] unwrap BinaryAccountData -> ${inner.runtimeType}');
    return extractBase64FromAccountData(inner, label: label);
  }

  // ---------------------------------------------------------------------------
  // Some RPC impls return RAW BYTES (Uint8List / List<int>) instead of base64.
  // Convert raw bytes -> base64 so the rest of your pipeline can stay the same.
  // ---------------------------------------------------------------------------
  if (data is Uint8List) {
    if (data.isEmpty) {
      icLogger.w('[$label] raw bytes is empty (Uint8List)');
      throw StateError('$label raw bytes is empty');
    }
    final b64 = base64Encode(data);
    //icLogger.d('[$label] encoded base64 from Uint8List (rawLen=${data.length}, b64Len=${b64.length})');
    return b64;
  }

  if (data is List<int>) {
    if (data.isEmpty) {
      icLogger.w('[$label] raw bytes is empty (List<int>)');
      throw StateError('$label raw bytes is empty');
    }
    final b64 = base64Encode(Uint8List.fromList(data));
    icLogger.d('[$label] encoded base64 from List<int> (rawLen=${data.length}, b64Len=${b64.length})');
    return b64;
  }

  // ---------------------------------------------------------------------------
  // Solana standard: ["<base64>", "base64"]
  // ---------------------------------------------------------------------------
  if (data is List) {
    if (data.isEmpty) {
      icLogger.w('[$label] data is empty List');
      throw StateError('$label base64 list is empty');
    }

    final first = data[0];
    if (first is String) {
      if (first.isEmpty) {
        icLogger.w('[$label] base64 string is empty (List form)');
        throw StateError('$label base64 is empty');
      }

      icLogger.d(
        '[$label] extracted base64 from List (len=${first.length}, encoding=${data.length > 1 ? data[1] : 'unknown'})',
      );
      return first;
    }

    icLogger.e('[$label] malformed List data[0] type=${first.runtimeType}, full=${data.runtimeType}');
    throw StateError('$label malformed account data (List[0] not String)');
  }

  // ---------------------------------------------------------------------------
  // Some wrappers normalize to: "<base64>"
  // ---------------------------------------------------------------------------
  if (data is String) {
    if (data.isEmpty) {
      icLogger.w('[$label] base64 string is empty (String form)');
      throw StateError('$label base64 is empty');
    }

    icLogger.d('[$label] extracted base64 from String (len=${data.length})');
    return data;
  }

  icLogger.e('[$label] malformed account data: type=${data.runtimeType}, value=$data');
  throw StateError('$label malformed account data (expected List/String/bytes, got ${data.runtimeType})');
}
