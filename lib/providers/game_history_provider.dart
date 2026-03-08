import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/models/winning_history_row.dart';
import 'package:iseefortune_flutter/services/history/history_api.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

class GameHistoryProvider extends ChangeNotifier {
  GameHistoryProvider({required WinningHistoryApi api}) : _api = api;

  final WinningHistoryApi _api;

  bool _started = false;
  bool _loading = false;
  Object? _error;

  List<WinningHistoryRow> _rows = const [];
  BigInt? _selectedEpoch;

  int _runId = 0; // protects against stale overwrites

  bool get isLoading => _loading;
  Object? get lastError => _error;

  List<WinningHistoryRow> get winningHistory => _rows;

  /// Assumes rows are sorted desc (newest first).
  BigInt? get latestEpoch => _rows.isEmpty ? null : _rows.first.epoch;

  /// If user never selected anything, default to latest.
  BigInt? get selectedEpoch => _selectedEpoch ?? latestEpoch;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_hydrate());
  }

  Future<void> refresh() => _hydrate();

  void selectEpoch(BigInt epoch) {
    if (_selectedEpoch == epoch) return;
    _selectedEpoch = epoch;
    notifyListeners();
  }

  Future<void> _hydrate() async {
    final myRun = ++_runId;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      icLogger.i('[GameHistoryProvider] loading winning history...');
      final resp = await _api.fetchWinningHistory(limit: 20);

      // If a newer run started while we were waiting, ignore this result.
      if (myRun != _runId) return;

      final nextRows = [...resp.items];

      // Ensure newest -> oldest (epoch desc)
      nextRows.sort((a, b) => b.epoch.compareTo(a.epoch));

      _rows = nextRows;

      // Default selection:
      // 1) keep user selection if it exists
      // 2) else use API lastEpoch
      // 3) else use latest in list
      _selectedEpoch ??= resp.lastEpoch ?? latestEpoch;

      // If selection no longer exists, fallback to latest
      if (_selectedEpoch != null && !_rows.any((r) => r.epoch == _selectedEpoch)) {
        _selectedEpoch = latestEpoch;
      }

      icLogger.i('[GameHistoryProvider] loaded count=${_rows.length} lastEpoch=${resp.lastEpoch}');
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (myRun != _runId) return;

      icLogger.w('[GameHistoryProvider] load failed: $e');
      _loading = false;
      _error = e;
      notifyListeners();
    }
  }

  /// Fast lookup: epoch -> winning number
  Map<BigInt, int> get winningByEpoch => {for (final r in _rows) r.epoch: r.winningNumber};
}
