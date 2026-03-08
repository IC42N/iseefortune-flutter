// lib/services/epoch_clock_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/models/epoch_clock_state.dart';
import 'package:iseefortune_flutter/solana/service/client.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:solana/solana.dart';

/// ---------------------------------------------------------------------------
/// EpochClockService
/// ---------------------------------------------------------------------------
/// Maintains a live, smooth epoch countdown for the UI.
///
/// Design goals:
/// - Accurate epoch/slot data from Solana RPC
/// - Smooth per-second UI updates without RPC spam
/// - Minimal drift over time
///
/// Strategy:
/// 1) Periodically sync authoritative epoch info from Solana RPC
/// 2) Locally "tick" every second to update countdown display
/// 3) Re-sync on a fixed interval to correct drift and slot index
///
/// This service is UI-facing and intended to be consumed via Provider
/// using Selector to keep rebuilds small and buttery.
/// ---------------------------------------------------------------------------
class EpochClockService extends ChangeNotifier {
  EpochClockService({
    /// How often the UI should update (purely local tick).
    Duration tickInterval = const Duration(seconds: 1),

    /// How often we re-sync with Solana RPC to prevent drift.
    Duration syncInterval = const Duration(seconds: 20),

    /// Fallback estimate for seconds per slot if RPC sampling fails.
    /// Solana averages ~400ms per slot, so 0.4 is a safe default.
    double fallbackSecondsPerSlot = 0.4,
  }) : _tickInterval = tickInterval,
       _syncInterval = syncInterval,
       _fallbackSecondsPerSlot = fallbackSecondsPerSlot;

  /// Interval for local UI ticking (no network calls).
  final Duration _tickInterval;

  /// Interval for authoritative RPC re-sync.
  final Duration _syncInterval;

  /// Fallback seconds-per-slot value when performance samples fail.
  final double _fallbackSecondsPerSlot;

  /// Timer for local per-second ticking.
  Timer? _tickTimer;

  /// Timer for periodic RPC synchronization.
  Timer? _syncTimer;

  /// Indicates whether the service has already been started.
  bool _started = false;

  /// Prevents overlapping RPC sync calls.
  bool _syncing = false;

  /// Latest known epoch clock state.
  EpochClockState? _state;

  /// Public read-only access to current epoch clock state.
  EpochClockState? get state => _state;

  /// True once the first successful sync has occurred.
  /// Useful for showing loading placeholders in UI.
  bool get hasState => _state != null;

  /// Starts the epoch clock.
  ///
  /// This should typically be called once:
  /// - after app bootstrap
  /// - or after wallet/network initialization
  ///
  /// Safe to call multiple times (idempotent).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Immediate sync so UI has real data ASAP.
    await _syncNow();

    // Local tick for smooth countdown updates.
    _tickTimer = Timer.periodic(_tickInterval, (_) => _tick());

    // Periodic RPC sync to refresh slot index and correct drift.
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _syncNow();
    });
  }

  /// Stops all timers and resets internal flags.
  ///
  /// Useful for app lifecycle events (background / foreground).
  void stop() {
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    _tickTimer = null;
    _syncTimer = null;
    _started = false;
    _syncing = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Local UI tick handler.
  ///
  /// This does NOT recompute slots or hit the network.
  /// It simply notifies listeners so countdown widgets
  /// can update based on wall-clock time.
  void _tick() {
    if (_state == null) return;

    // Avoid unnecessary notifications if nothing is listening.
    if (!hasListeners) return;

    notifyListeners();
  }

  /// Performs an authoritative sync with Solana RPC.
  ///
  /// Fetches:
  /// - current epoch
  /// - slot index within epoch
  /// - total slots in epoch
  /// - recent performance samples (to estimate seconds per slot)
  ///
  /// Then computes an estimated local epoch end time.
  Future<void> _syncNow() async {
    if (_syncing) return;
    _syncing = true;

    final rpc = SolanaClientService().rpcClient;

    try {
      // Fetch authoritative epoch info from cluster.
      final info = await rpc.getEpochInfo();

      // Estimate average seconds per slot.
      final secPerSlot = await _estimateSecondsPerSlot(rpc);

      final now = DateTime.now();

      // Convert to int early to avoid clamp/type issues.
      final slotsInEpoch = info.slotsInEpoch.toInt();
      final slotIndex = info.slotIndex.toInt();

      // Remaining slots in the current epoch.
      final slotsRemaining = (slotsInEpoch - slotIndex).clamp(0, slotsInEpoch);

      // Estimate epoch end based on remaining slots.
      final remainingSeconds = (slotsRemaining * secPerSlot).round();
      final estimatedEnd = now.add(Duration(seconds: remainingSeconds));

      // Update state.
      _state = EpochClockState(
        epoch: info.epoch.toInt(),
        slotIndex: slotIndex,
        slotsInEpoch: slotsInEpoch,
        estimatedSecondsPerSlot: secPerSlot,
        syncedAt: now,
        estimatedEpochEndAt: estimatedEnd,
      );

      notifyListeners();
    } catch (e, st) {
      // On failure, keep previous state and allow UI to keep ticking.
      icLogger.w('EpochClockService: sync failed', error: e, stackTrace: st);
    } finally {
      _syncing = false;
    }
  }

  /// Estimates the average seconds per slot using recent performance samples.
  ///
  /// Uses `getRecentPerformanceSamples` when available.
  /// Falls back to [_fallbackSecondsPerSlot] if:
  /// - RPC call fails
  /// - no samples are returned
  /// - values are invalid
  ///
  /// Result is clamped to a sane range to avoid wild UI jumps.
  Future<double> _estimateSecondsPerSlot(RpcClient rpc) async {
    try {
      final samples = await rpc.getRecentPerformanceSamples(5);

      if (samples.isEmpty) return _fallbackSecondsPerSlot;

      int totalSlots = 0;
      int totalSeconds = 0;

      for (final s in samples) {
        totalSlots += s.numSlots.toInt();
        totalSeconds += s.samplePeriodSecs.toInt();
      }

      if (totalSlots <= 0 || totalSeconds <= 0) {
        return _fallbackSecondsPerSlot;
      }

      final est = totalSeconds / totalSlots;

      if (!est.isFinite || est <= 0) return _fallbackSecondsPerSlot;

      // Clamp to realistic Solana slot timings.
      return est.clamp(0.25, 1.5);
    } catch (_) {
      return _fallbackSecondsPerSlot;
    }
  }
}
