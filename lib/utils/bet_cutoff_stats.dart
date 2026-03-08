class BetCutoffStats {
  const BetCutoffStats({
    required this.betCutoffSlots, // config (slots before epoch end)
    required this.slotsRemaining, // slots UNTIL CUTOFF (already computed)
    required this.etaSecondsRemaining, // seconds UNTIL CUTOFF (already computed)
  });

  final int betCutoffSlots;
  final int slotsRemaining;
  final int etaSecondsRemaining;

  /// Betting is open as long as we have at least 1 slot left before cutoff.
  bool get isBettingOpen => slotsRemaining > 0;

  /// Alias for readability.
  int get slotsUntilCutoff => slotsRemaining;

  /// Alias for readability.
  int get etaSecondsUntilCutoff => etaSecondsRemaining;
}
