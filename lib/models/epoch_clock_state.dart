// lib/services/epoch_clock_state.dart

/// Snapshot of the current epoch timing state.
/// This is what your UI reads.
class EpochClockState {
  EpochClockState({
    required this.epoch,
    required this.slotIndex,
    required this.slotsInEpoch,
    required this.estimatedSecondsPerSlot,
    required this.syncedAt,
    required this.estimatedEpochEndAt,
  });

  final int epoch;
  final int slotIndex;
  final int slotsInEpoch;
  final double estimatedSecondsPerSlot;
  final DateTime syncedAt;
  final DateTime estimatedEpochEndAt;

  /// Slots remaining until epoch ends (authoritative snapshot).
  int get slotsRemaining => (slotsInEpoch - slotIndex).clamp(0, slotsInEpoch);

  /// Progress through epoch (0.0..1.0) (authoritative snapshot).
  double get progress {
    if (slotsInEpoch <= 0) return 0;
    return (slotIndex / slotsInEpoch).clamp(0.0, 1.0);
  }

  /// Estimated time remaining until epoch end (Duration).
  Duration get estimatedTimeRemaining {
    final diff = estimatedEpochEndAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // ---------------------------------------------------------------------------
  // Smooth / locally-estimated values (updates every tick without RPC)
  // ---------------------------------------------------------------------------

  /// How many slots have likely elapsed since the last RPC sync.
  /// Uses wall clock time and estimatedSecondsPerSlot.
  int get _estimatedSlotsSinceSync {
    if (estimatedSecondsPerSlot <= 0 || !estimatedSecondsPerSlot.isFinite) return 0;

    final elapsedMs = DateTime.now().difference(syncedAt).inMilliseconds;
    if (elapsedMs <= 0) return 0;

    final elapsedSec = elapsedMs / 1000.0;

    // floor so we only advance when we likely passed a slot boundary
    final est = (elapsedSec / estimatedSecondsPerSlot).floor();
    if (est < 0) return 0;
    return est;
  }

  /// Estimated slot index "now" (clamped).
  ///
  /// This is what your UI should use for smooth progress animation.
  int get estimatedSlotIndexNow {
    if (slotsInEpoch <= 0) return 0;
    final est = slotIndex + _estimatedSlotsSinceSync;
    return est.clamp(0, slotsInEpoch);
  }

  /// Estimated slots remaining "now" (clamped).
  int get estimatedSlotsRemainingNow {
    if (slotsInEpoch <= 0) return 0;
    return (slotsInEpoch - estimatedSlotIndexNow).clamp(0, slotsInEpoch);
  }

  /// Estimated progress "now" (0.0..1.0).
  double get estimatedProgressNow {
    if (slotsInEpoch <= 0) return 0;
    return (estimatedSlotIndexNow / slotsInEpoch).clamp(0.0, 1.0);
  }

  EpochClockState copyWith({
    int? epoch,
    int? slotIndex,
    int? slotsInEpoch,
    double? estimatedSecondsPerSlot,
    DateTime? syncedAt,
    DateTime? estimatedEpochEndAt,
  }) {
    return EpochClockState(
      epoch: epoch ?? this.epoch,
      slotIndex: slotIndex ?? this.slotIndex,
      slotsInEpoch: slotsInEpoch ?? this.slotsInEpoch,
      estimatedSecondsPerSlot: estimatedSecondsPerSlot ?? this.estimatedSecondsPerSlot,
      syncedAt: syncedAt ?? this.syncedAt,
      estimatedEpochEndAt: estimatedEpochEndAt ?? this.estimatedEpochEndAt,
    );
  }
}
