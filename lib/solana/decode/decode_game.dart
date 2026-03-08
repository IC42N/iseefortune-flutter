import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:iseefortune_flutter/models/game/game_pda_model.dart';

ResolvedGameModel decodeResolvedGame(Uint8List accountBytes) {
  final payload = accountBytes.sublist(8); // strip Anchor discriminator
  return borsh.deserialize(ResolvedGameModel.staticSchema, payload, ResolvedGameModel.fromJson);
}
