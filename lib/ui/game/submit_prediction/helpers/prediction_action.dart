enum PredictionAction { place, changeNumber, increase }

extension PredictionActionUi on PredictionAction {
  String get wireValue => switch (this) {
    PredictionAction.place => 'place',
    PredictionAction.changeNumber => 'change_number',
    PredictionAction.increase => 'increase',
  };

  String get title => switch (this) {
    PredictionAction.place => 'Place Prediction',
    PredictionAction.changeNumber => 'Change Number',
    PredictionAction.increase => 'Increase Amount',
  };

  String get subtitle => switch (this) {
    PredictionAction.place => 'Choose a mode, pick, and submit.',
    PredictionAction.changeNumber => 'Update your selection for this epoch.',
    PredictionAction.increase => 'Add more SOL to your current prediction.',
  };
}
