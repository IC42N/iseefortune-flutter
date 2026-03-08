import 'dart:typed_data';
import 'package:solana/solana.dart';

Ed25519HDPublicKey parsePubkey(dynamic v, {required String label}) {
  if (v is Ed25519HDPublicKey) return v;

  // solana_borsh commonly returns base58 here
  if (v is String) return Ed25519HDPublicKey.fromBase58(v);

  // sometimes it might be List<int> or Uint8List
  if (v is Uint8List) return Ed25519HDPublicKey(v);
  if (v is List) return Ed25519HDPublicKey(Uint8List.fromList(v.cast<int>()));

  throw StateError('$label: unsupported pubkey type ${v.runtimeType}');
}

Uint8List parseU8Array(dynamic v, {required int len, required String label}) {
  if (v is Uint8List) {
    if (v.length != len) throw StateError('$label: expected len=$len, got ${v.length}');
    return v;
  }
  if (v is List) {
    final out = Uint8List.fromList(v.cast<int>());
    if (out.length != len) throw StateError('$label: expected len=$len, got ${out.length}');
    return out;
  }
  throw StateError('$label: unsupported u8 array type ${v.runtimeType}');
}
