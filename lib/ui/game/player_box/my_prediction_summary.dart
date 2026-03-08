import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

class MyPredictionSummary {
  const MyPredictionSummary({
    required this.predictionLabel,
    required this.selections,
    required this.amountLabel,
    required this.isClaimed,
  });

  final String predictionLabel;
  final List<int> selections;
  final String amountLabel;
  final bool isClaimed;
}

/// UI helper: turn a PredictionModel into the exact strings the PlayerBox wants.
MyPredictionSummary buildMyPredictionSummary(PredictionModel p) {
  final selections = [...p.activeSelections]..sort();

  if (selections.isEmpty) {
    return MyPredictionSummary(
      predictionLabel: 'Your Prediction',
      selections: const [],
      amountLabel: '',
      isClaimed: p.isClaimed,
    );
  }

  final amountLabel = selections.length == 1
      ? '${lamportsToSolText(p.lamports)} SOL'
      : '${lamportsToSolText(p.lamportsPerNumber)} SOL each';

  return MyPredictionSummary(
    predictionLabel: 'Your Prediction',
    selections: selections,
    amountLabel: amountLabel,
    isClaimed: p.isClaimed,
  );
}
