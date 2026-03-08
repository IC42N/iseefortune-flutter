import 'dart:async';

enum WalletConnectorStatus { idle, connecting, connected, disconnected, error }

abstract class WalletConnector {
  String get id; // e.g. "mwa", "seed_vault"
  WalletConnectorStatus get status;

  String? get pubkey;

  Stream<String?> get pubkeyStream;

  Future<void> init();

  /// Best-effort restore (no UI prompt if possible).
  /// Returns true if restored to a connected state.
  Future<bool> tryRestore();

  /// User-initiated connect (can open wallet UI / prompt user).
  Future<void> connect();

  Future<void> disconnect();
}
