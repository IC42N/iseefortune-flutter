import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/services/price_service.dart';

class PriceProvider extends ChangeNotifier with WidgetsBindingObserver {
  PriceProvider({SolPriceService? service, Duration interval = const Duration(minutes: 1)})
    : _service = service ?? SolPriceService(),
      _interval = interval {
    WidgetsBinding.instance.addObserver(this);
    _startPolling(); // immediate + periodic
  }

  final SolPriceService _service;
  final Duration _interval;

  double? _solUsd;
  bool _isLoading = false;
  DateTime? _lastUpdated;
  Timer? _timer;
  bool _paused = false;

  double? get solUsd => _solUsd;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  Future<void> refreshNow() => _fetch(); // for pull-to-refresh

  // Lifecycle: pause/resume polling to save battery/work
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _startPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _paused = true;
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    // fire once immediately
    unawaited(_fetch());
    // then schedule periodic
    _timer = Timer.periodic(_interval, (_) => _fetch());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetch() async {
    if (_paused) return;
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final v = await _service.fetch(); // returns double? with internal cache/backoff
      // Only notify on meaningful change
      final changed = v != _solUsd;
      _solUsd = v;
      _lastUpdated = DateTime.now();
      if (changed || _isLoading) notifyListeners();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }
}
