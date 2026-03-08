import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:iseefortune_flutter/models/config_model.dart';

ConfigModel decodeConfigFromAccountBytes(Uint8List rawAccountBytes) {
  // Anchor accounts start with 8-byte discriminator
  final sliced = rawAccountBytes.sublist(8);
  return borsh.deserialize(ConfigModel.staticSchema, sliced, ConfigModel.fromJson);
}
