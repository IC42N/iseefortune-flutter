import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/shared/cosmic_modal.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/submit_prediction_modal.dart';

Future<void> openSubmitPredictionModal(
  BuildContext context, {
  required PredictionAction action,
  SubmitModalEntry entry = SubmitModalEntry.create,
  Uint8List? initialSelections,
  BigInt? initialLamportsPerNumber,
}) async {
  await CosmicModal.show(
    context,
    title: entry == SubmitModalEntry.manage ? 'MANAGE PREDICTION' : 'SUBMIT PREDICTION',
    hueDeg: 200,
    isScrollControlled: true,
    enableDrag: true,
    radius: 12,
    showClouds: false,
    showHands: false,
    child: SubmitPredictionModal(
      action: action,
      entry: entry,
      initialNumbers: initialSelections,
      initialLamportsPerNumber: initialLamportsPerNumber,
    ),
  );
}
