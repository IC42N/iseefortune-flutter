import 'dart:convert';
import 'dart:typed_data';

Uint8List accountBytesFromBase64(String base64Data) {
  return Uint8List.fromList(base64Decode(base64Data));
}

Uint8List stripAnchorDiscriminator(Uint8List raw, {String label = 'Account'}) {
  if (raw.length < 8) {
    throw StateError('$label data too short for Anchor discriminator (len=${raw.length})');
  }
  return raw.sublist(8);
}
