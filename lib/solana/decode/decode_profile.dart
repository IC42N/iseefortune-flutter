import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:iseefortune_flutter/models/profile/profile_pda_model.dart';

PlayerProfilePDAModel decodePlayerProfile(Uint8List accountBytes) {
  final payload = accountBytes.sublist(8); // remove Anchor discriminator
  return borsh.deserialize(PlayerProfilePDAModel.staticSchema, payload, PlayerProfilePDAModel.fromJson);
}
