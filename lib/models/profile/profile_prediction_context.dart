class ProfilePredictionContext {
  const ProfilePredictionContext({required this.currentEpoch, required this.winningByEpoch});

  final BigInt currentEpoch;

  /// Map: epoch -> winning number (1-9)
  final Map<BigInt, int> winningByEpoch;
}
