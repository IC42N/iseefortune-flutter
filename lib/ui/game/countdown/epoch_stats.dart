class EpochStats {
  const EpochStats({
    required this.slotIndex,
    required this.slotsInEpoch,
    required this.slotsLeft,
    required this.etaSeconds,
  });

  final int slotIndex;
  final int slotsInEpoch;
  final int slotsLeft;
  final int etaSeconds;

  @override
  bool operator ==(Object other) =>
      other is EpochStats &&
      other.slotIndex == slotIndex &&
      other.slotsInEpoch == slotsInEpoch &&
      other.slotsLeft == slotsLeft &&
      other.etaSeconds == etaSeconds;

  @override
  int get hashCode => Object.hash(slotIndex, slotsInEpoch, slotsLeft, etaSeconds);
}
