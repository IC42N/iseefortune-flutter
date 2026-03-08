import 'package:solana/solana.dart';

/// Converts a base58 string address into an Ed25519HDPublicKey.
/// Throws [FormatException] if the address is invalid.
Ed25519HDPublicKey toPublicKey(String address) {
  return Ed25519HDPublicKey.fromBase58(address);
}

String getHandleFromPubkey(String pubkey, {int length = 4}) {
  if (pubkey.length <= 10) return pubkey;
  return '${pubkey.substring(0, length).toUpperCase()}${pubkey.substring(pubkey.length - length).toUpperCase()}';
}

String shortPDA(String s) {
  if (s.length <= 8) return s;
  return '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
}

String shortBlockHash(String s) {
  if (s.length <= 10) return s;
  return '${s.substring(0, 10)}…${s.substring(s.length - 10)}';
}
