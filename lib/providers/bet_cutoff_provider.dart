import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/services/epoch_clock_service.dart';
import 'package:iseefortune_flutter/utils/bet_cutoff_stats.dart';

class BetCutoffProvider extends ChangeNotifier {
  BetCutoffStats? _stats;
  bool _justClosed = false;

  BetCutoffStats? get stats => _stats;
  bool get hasData => _stats != null && (_stats!.betCutoffSlots > 0);
  int get secondsUntilCutoff => _stats?.etaSecondsUntilCutoff ?? 0;
  bool consumeJustClosed() {
    final v = _justClosed;
    _justClosed = false;
    return v;
  }

  bool get bettingOpen {
    final s = _stats;
    if (s == null) return true; // or false if you prefer strict lock
    if (s.betCutoffSlots <= 0) return true; // config not loaded yet
    return s.isBettingOpen;
  }

  bool get isSynced {
    final s = _stats;
    return s != null && s.betCutoffSlots > 0;
  }

  void update({required ConfigProvider config, required EpochClockService clock}) {
    final cutoffSlots = config.config?.betCutoffSlots.toInt() ?? 0;

    final st = clock.state;

    final slotsInEpoch = st?.slotsInEpoch ?? 0;
    final slotNow = st?.estimatedSlotIndexNow ?? 0;
    final secondsPerSlot = st?.estimatedSecondsPerSlot ?? 0.0;

    int slotsUntilCutoff = 0;
    int etaSecondsUntilCutoff = 0;

    if (slotsInEpoch > 0 && cutoffSlots > 0 && secondsPerSlot > 0) {
      final cutoffSlotIndex = (slotsInEpoch - cutoffSlots).clamp(0, slotsInEpoch);
      slotsUntilCutoff = (cutoffSlotIndex - slotNow).clamp(0, slotsInEpoch);
      etaSecondsUntilCutoff = (slotsUntilCutoff * secondsPerSlot).round();
    } else {
      // If we can’t compute cutoff yet, keep it at 0.
      // Your UI already shows “…” when not synced.
    }

    final next = BetCutoffStats(
      betCutoffSlots: cutoffSlots,
      slotsRemaining: slotsUntilCutoff,
      etaSecondsRemaining: etaSecondsUntilCutoff,
    );

    final prevOpen = _stats?.isBettingOpen ?? true;
    final nextOpen = next.isBettingOpen;

    if (prevOpen && !nextOpen) _justClosed = true;

    if (_stats == null ||
        _stats!.betCutoffSlots != next.betCutoffSlots ||
        _stats!.slotsRemaining != next.slotsRemaining ||
        _stats!.etaSecondsRemaining != next.etaSecondsRemaining) {
      _stats = next;
      notifyListeners();
    }
  }
}
