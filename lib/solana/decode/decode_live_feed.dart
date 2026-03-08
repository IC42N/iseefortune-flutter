import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:iseefortune_flutter/models/live_feed_model.dart';

/// Decode helper
/// ---------------------------------------------------------------------------
/// Anchor accounts include an 8-byte discriminator prefix.
/// This accepts *full account bytes* (discriminator + borsh body),
/// strips the first 8 bytes, and deserializes the LiveFeed.
LiveFeedModel decodeLiveFeedFromAccountBytes(Uint8List rawAccountBytes) {
  if (rawAccountBytes.length < 8) {
    throw Exception('LiveFeed account data too short: ${rawAccountBytes.length}');
  }
  final body = rawAccountBytes.sublist(8);
  return borsh.deserialize(LiveFeedModel.staticSchema, body, LiveFeedModel.fromJson);
}
