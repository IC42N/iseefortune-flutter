import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';

PredictionModel decodePredictionFromAccountBytes(Uint8List accountBytes) {
  final payload = accountBytes.sublist(8); // remove 8-byte Anchor discriminator
  return borsh.deserialize(PredictionModel.staticSchema, payload, PredictionModel.fromJson);
}
