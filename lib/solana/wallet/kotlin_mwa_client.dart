import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

/// Thin Dart bridge over the native Kotlin Mobile Wallet Adapter plugin.
///
/// This class talks to the Kotlin plugin through a MethodChannel:
/// - connect
/// - disconnect
/// - signTransaction
///
/// Responsibilities:
/// - request interactive wallet authorization
/// - receive selected wallet pubkey + auth token
/// - request wallet-side signing for serialized transactions
///
/// Notes:
/// - This class does NOT build transactions.
/// - This class does NOT send transactions to Solana RPC.
/// - This class does NOT confirm transactions on-chain.
/// - It only forwards requests to the Kotlin MWA layer and normalizes responses.
class KotlinMwaClient {
  KotlinMwaClient({MethodChannel? channel}) : _ch = channel ?? const MethodChannel('mwa_clientlib');

  /// MethodChannel connected to the native Kotlin plugin.
  final MethodChannel _ch;

  // ---------------------------------------------------------------------------
  // CONNECT
  // ---------------------------------------------------------------------------

  /// Opens the native MWA wallet connect / authorize flow.
  ///
  /// On success, returns:
  /// - selected wallet pubkey bytes
  /// - selected wallet pubkey base58 string
  /// - opaque auth token returned by the native wallet session
  ///
  /// Returns null when:
  /// - the user cancels
  /// - Kotlin returns an incomplete success payload
  ///
  /// Throws when:
  /// - Kotlin reports a non-cancel failure
  /// - native response shape is invalid
  Future<KotlinConnectResult?> connectSafe() async {
    icLogger.i('[KotlinMwaClient] connectSafe() start');

    final Map res = await _ch.invokeMethod('connect');

    icLogger.i('[KotlinMwaClient] connectSafe() raw ok=${res['ok']} code=${res['code']}');
    icLogger.i('[KotlinMwaClient] connectSafe() publicKeyB58=${res['publicKeyB58']}');
    icLogger.i(
      '[KotlinMwaClient] connectSafe() authTokenPresent=${res['authToken'] != null && res['authToken'].toString().isNotEmpty}',
    );
    icLogger.i('[KotlinMwaClient] connectSafe() publicKeyBytesType=${res['publicKeyBytes']?.runtimeType}');

    final ok = res['ok'] == true;
    if (!ok) {
      final code = res['code']?.toString() ?? 'FAILURE';
      final msg = res['message']?.toString() ?? 'Unknown error';
      final etype = res['etype']?.toString();

      icLogger.e('[KotlinMwaClient] connectSafe() failed code=$code etype=$etype msg=$msg');

      if (code == 'CANCELED') return null;

      throw StateError('MWA connect failed: $code ${etype ?? ''} $msg');
    }

    final publicKeyB58 = res['publicKeyB58']?.toString();
    final authToken = res['authToken']?.toString();
    final publicKeyBytes = res['publicKeyBytes'];

    if (publicKeyB58 == null || publicKeyB58.isEmpty) {
      icLogger.e('[KotlinMwaClient] connectSafe() missing publicKeyB58');
      return null;
    }

    if (authToken == null || authToken.isEmpty) {
      icLogger.e('[KotlinMwaClient] connectSafe() missing authToken');
      return null;
    }

    final pkBytes = publicKeyBytes is Uint8List
        ? publicKeyBytes
        : Uint8List.fromList(List<int>.from(publicKeyBytes));

    icLogger.i('[KotlinMwaClient] connectSafe() success pkLen=${pkBytes.length}');

    return KotlinConnectResult(publicKeyBytes: pkBytes, publicKeyB58: publicKeyB58, authToken: authToken);
  }

  // ---------------------------------------------------------------------------
  // DISCONNECT
  // ---------------------------------------------------------------------------

  /// Requests native MWA disconnect / local session clear.
  ///
  /// This method is intentionally simple:
  /// - ask Kotlin to clear its local/native session state
  /// - throw if native reports failure
  Future<void> disconnectSafe() async {
    icLogger.i('[KotlinMwaClient] disconnectSafe() start');

    final Map<dynamic, dynamic> res = await _ch.invokeMethod('disconnect');

    icLogger.i('[KotlinMwaClient] disconnectSafe() raw ok=${res['ok']} code=${res['code']}');

    final ok = res['ok'] == true;
    if (!ok) {
      final msg = res['message']?.toString() ?? 'Unknown disconnect error';
      icLogger.e('[KotlinMwaClient] disconnectSafe() failed msg=$msg');
      throw StateError(msg);
    }

    icLogger.i('[KotlinMwaClient] disconnectSafe() success');
  }

  // ---------------------------------------------------------------------------
  // SIGN TRANSACTION
  // ---------------------------------------------------------------------------

  /// Requests the native Kotlin MWA layer to sign a transaction.
  ///
  /// Expects:
  /// - [transactionB64] to contain a FULL serialized unsigned Solana transaction
  ///
  /// Returns:
  /// - signed transaction bytes as base64-decoded Uint8List
  ///
  /// Notes:
  /// - The wallet signs only.
  /// - Sending and confirming should happen in Flutter at a higher layer.
  Future<Uint8List> signTransactionB64({required String transactionB64}) async {
    icLogger.i('[KotlinMwaClient] signTransactionB64() start');
    icLogger.i('[KotlinMwaClient] signTransactionB64() transactionB64Len=${transactionB64.length}');

    final Map<dynamic, dynamic> res = await _ch.invokeMethod('signTransaction', {
      'transactionB64': transactionB64,
    });

    icLogger.i('[KotlinMwaClient] signTransactionB64() raw ok=${res['ok']} code=${res['code']}');

    if (res['ok'] != true) {
      final code = '${res['code'] ?? 'ERR'}';
      final msg = '${res['message'] ?? 'unknown'}';
      final etype = res['etype']?.toString();

      icLogger.e('[KotlinMwaClient] signTransactionB64() failed code=$code etype=$etype msg=$msg');
      throw StateError('$code: $msg');
    }

    final signedTxB64 = res['signedTransactionB64'] as String?;
    if (signedTxB64 == null || signedTxB64.isEmpty) {
      icLogger.e('[KotlinMwaClient] signTransactionB64() missing signedTransactionB64');
      throw StateError('Missing signedTransactionB64');
    }

    final signedTxBytes = Uint8List.fromList(base64Decode(signedTxB64));
    icLogger.i('[KotlinMwaClient] signTransactionB64() success signedTxLen=${signedTxBytes.length}');
    return signedTxBytes;
  }
}

/// Result returned after a successful native MWA connect.
///
/// Contains the minimum wallet/session data needed by Dart-side state:
/// - wallet pubkey bytes
/// - wallet pubkey base58
/// - opaque auth token
class KotlinConnectResult {
  /// 32-byte wallet public key.
  final Uint8List publicKeyBytes;

  /// Wallet public key encoded in base58.
  final String publicKeyB58;

  /// Opaque native wallet auth token / session token.
  final String authToken;

  KotlinConnectResult({required this.publicKeyBytes, required this.publicKeyB58, required this.authToken});

  /// Creates a strongly typed connect result from a MethodChannel map.
  ///
  /// Kotlin byte[] may arrive as:
  /// - Uint8List
  /// - List<dynamic>
  factory KotlinConnectResult.fromMap(Map<dynamic, dynamic> m) {
    final dynamic rawBytes = m['publicKeyBytes'];
    final Uint8List pkBytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList(List<int>.from(rawBytes as List));

    final String pkB58 = (m['publicKeyB58'] ?? '').toString();
    final String token = (m['authToken'] ?? '').toString();

    return KotlinConnectResult(publicKeyBytes: pkBytes, publicKeyB58: pkB58, authToken: token);
  }
}
