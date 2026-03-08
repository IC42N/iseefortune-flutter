import 'dart:typed_data';

import 'package:iseefortune_flutter/solana/wallet/kotlin_mwa_client.dart';
import 'package:solana/base58.dart' show base58decode;

/// Result of an interactive MWA connect/authorize.
class WalletAuthResult {
  WalletAuthResult({
    required this.authToken,
    required this.publicKey,
    required this.addressB58,
    this.walletUriBase,
  });

  /// Opaque auth token returned by the Kotlin MobileWalletAdapter bridge.
  final String authToken;

  /// 32-byte pubkey bytes of the selected account.
  final Uint8List publicKey;

  /// Base58 address string.
  final String addressB58;

  /// Optional wallet base URI used for targeting the same wallet on future requests.
  final Uri? walletUriBase;
}

/// Dart-side service that wraps the Kotlin MWA client plugin via MethodChannel.
///
/// Current Kotlin plugin API:
/// - connect()
/// - disconnect()
/// - signTransaction(transactionB64)
///
/// This service also caches light Dart-side session state for the UI/provider.
class SolanaWalletAdapterService {
  SolanaWalletAdapterService({required this.cluster, required KotlinMwaClient client}) : _client = client;

  /// Cluster kept for future use.
  final String cluster;

  final KotlinMwaClient _client;

  // ---------------------------------------------------------------------------
  // Session-ish state cached on the Dart side (Provider consumes this)
  // ---------------------------------------------------------------------------

  String? _authToken;
  String? _activeAddressB58;
  Uint8List? _activePubkeyBytes;

  String? get authToken => _authToken;
  String? get activeAddressB58 => _activeAddressB58;
  Uint8List? get activePubkeyBytes => _activePubkeyBytes;

  bool get hasSession =>
      (_authToken != null && _authToken!.isNotEmpty) &&
      (_activeAddressB58 != null && _activeAddressB58!.isNotEmpty);

  // ---------------------------------------------------------------------------
  // Session helpers
  // ---------------------------------------------------------------------------

  /// Clears only Dart-side cached values.
  void clearLocalSession() {
    _authToken = null;
    _activeAddressB58 = null;
    _activePubkeyBytes = null;
  }

  /// Restores Dart-side cached wallet session values.
  ///
  /// This is mainly useful for UI/provider state. Native MWA authorization
  /// reuse is handled on the Kotlin side.
  void restoreLocalSession({
    required String authToken,
    required String activeAddressB58,
    Uint8List? activePubkeyBytes,
  }) {
    if (authToken.isEmpty) throw ArgumentError('authToken empty');
    if (activeAddressB58.isEmpty) throw ArgumentError('activeAddressB58 empty');

    final pkBytes = activePubkeyBytes ?? Uint8List.fromList(base58decode(activeAddressB58));
    if (pkBytes.length != 32) {
      throw StateError('MWA restored pubkey bytes len=${pkBytes.length}, expected 32');
    }

    _authToken = authToken;
    _activeAddressB58 = activeAddressB58;
    _activePubkeyBytes = pkBytes;
  }

  // ---------------------------------------------------------------------------
  // Auth (interactive)
  // ---------------------------------------------------------------------------

  /// Interactive wallet connect.
  ///
  /// Returns null if user cancels or connect fails gracefully.
  Future<WalletAuthResult?> authorize() async {
    final res = await _client.connectSafe();
    if (res == null) return null;

    final pkBytes = res.publicKeyBytes;
    if (pkBytes.length != 32) {
      throw StateError('MWA pubkey bytes len=${pkBytes.length}, expected 32');
    }

    final addressB58 = res.publicKeyB58;
    final token = res.authToken;

    _authToken = token;
    _activeAddressB58 = addressB58;
    _activePubkeyBytes = pkBytes;

    return WalletAuthResult(
      authToken: token,
      publicKey: pkBytes,
      addressB58: addressB58,
      walletUriBase: null,
    );
  }

  /// Disconnect / deauthorize.
  ///
  /// Always clears Dart-side state after calling native disconnect.
  Future<void> deauthorize({bool interactive = false}) async {
    await _client.disconnectSafe();
    await Future.delayed(const Duration(milliseconds: 500));
    clearLocalSession();
  }

  Future<bool> isWalletAvailable() async => true;

  // ---------------------------------------------------------------------------
  // Sign transaction
  // ---------------------------------------------------------------------------

  /// Ask the Kotlin MWA bridge to sign a serialized unsigned Solana transaction.
  ///
  /// Expects `transactionB64` to be a FULL serialized unsigned transaction,
  /// not just versioned message bytes.
  ///
  /// Returns the signed transaction bytes.
  Future<Uint8List> signTransactionB64({required String transactionB64}) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      throw StateError('MWA missing auth token; connect wallet first');
    }

    return _client.signTransactionB64(transactionB64: transactionB64);
  }
}
