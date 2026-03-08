import 'dart:typed_data';

/// Signs a Solana *VersionedMessage* (the bytes you get from your Lambda message_b64).
/// Must return a single 64-byte Ed25519 signature.
abstract class VersionedTxSigner {
  Future<Uint8List> signMessageBytes(Uint8List messageBytes);
}
