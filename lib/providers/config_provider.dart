import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:iseefortune_flutter/models/config_model.dart';
import 'package:iseefortune_flutter/models/tier_model.dart';
import 'package:iseefortune_flutter/services/config_service.dart';

/// ConfigProvider (attach-style)
/// ---------------------------------------------------------------------------
/// UI-facing reactive state for the global Config PDA.
///
/// Responsibilities:
/// - Fetch the Config snapshot on boot (HTTP).
/// - Optionally stay in sync via WebSocket.
/// - Expose tier-related helpers for UI logic (min/max wager, active tiers).
///
/// Design notes:
/// - This provider OWNS on-chain config state.
/// - It does NOT derive PDAs, manage RPC plumbing, or persist to disk.
/// - Tier selection (which tier the user chose) lives elsewhere (TierProvider).
class ConfigProvider extends ChangeNotifier {
  ConfigProvider({this.enableSubscription = true});

  /// Whether to subscribe to live config updates via WebSocket
  final bool enableSubscription;

  /// Injected service responsible for fetching/subscribing to config
  ConfigService? _service;

  /// Latest Config snapshot (null until loaded)
  ConfigModel? _config;

  /// Loading + error state for UI gating
  bool _isLoading = false;
  Object? _lastError;

  /// Active WebSocket subscription (if enabled)
  StreamSubscription<ConfigModel>? _wsSub;

  /// Monotonic nonce used to invalidate in-flight async work
  /// (prevents race conditions when reloading)
  int _nonce = 0;

  /// Indicates whether `start()` has been called
  bool _started = false;

  // ---------------------------------------------------------------------------
  // Public read-only state
  // ---------------------------------------------------------------------------

  ConfigModel? get config => _config;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;
  bool get hasData => _config != null;

  /// Safe indicator for UI:
  /// - Config exists
  /// - Not currently loading
  bool get isReady => _config != null && !_isLoading;

  // ---------------------------------------------------------------------------
  // Tier helpers (UI-facing convenience)
  // ---------------------------------------------------------------------------
  // These helpers keep tier logic OUT of widgets and avoid duplication.
  // They assume tier rules come from on-chain config (authoritative source).

  /// Returns TierSettings for the given tierId, or null if missing / not loaded.
  TierSettings? tierSettings(int tierId) {
    final cfg = _config;
    if (cfg == null) return null;

    final tiers = cfg.tiers;
    for (final t in tiers) {
      if (t.tierId == tierId) return t;
    }
    return null;
  }

  /// Whether a tier exists in the config
  bool hasTier(int tierId) => tierSettings(tierId) != null;

  /// Whether a tier exists AND is active
  bool isTierActive(int tierId) {
    final t = tierSettings(tierId);
    return t != null && t.isActive;
  }

  /// Raw lamport limits for a tier (authoritative values)
  BigInt? tierMinLamports(int tierId) => tierSettings(tierId)?.minBetLamports;
  BigInt? tierMaxLamports(int tierId) => tierSettings(tierId)?.maxBetLamports;

  /// Convenience helpers for UI (SOL instead of lamports)
  double? tierMinSol(int tierId) {
    final v = tierMinLamports(tierId);
    if (v == null) return null;
    return v.toDouble() / 1e9;
  }

  double? tierMaxSol(int tierId) {
    final v = tierMaxLamports(tierId);
    if (v == null) return null;
    return v.toDouble() / 1e9;
  }

  /// Clamp a per-number wager into the tier’s min/max bounds.
  ///
  /// Used by wager UI to prevent invalid slider values.
  /// Returns null if config not ready or tier missing.
  double? clampPerNumberSolForTier(int tierId, double perNumberSol) {
    final min = tierMinSol(tierId);
    final max = tierMaxSol(tierId);
    if (min == null || max == null) return null;

    if (perNumberSol < min) return min;
    if (perNumberSol > max) return max;
    return perNumberSol;
  }

  // ---------------------------------------------------------------------------
  // Service lifecycle (attach / start)
  // ---------------------------------------------------------------------------

  /// Attach the ConfigService.
  ///
  /// This is separated from `start()` so dependency injection
  /// order does not matter during app bootstrap.
  void attachService(ConfigService service) {
    if (identical(_service, service)) return;
    _service = service;

    // If not started yet, defer loading
    if (!_started) return;

    // If config already exists, just ensure WS is running
    if (hasData) {
      if (enableSubscription && _wsSub == null) {
        unawaited(_startSubscription(service));
      }
      return;
    }

    // Otherwise do a normal load
    unawaited(loadAndSubscribe());
  }

  /// Start loading config.
  ///
  /// Called once from AppBootstrapper after initial setup.
  /// Safe to call multiple times.
  void start() {
    if (_started) return;
    _started = true;

    final service = _service;
    if (service == null) return;

    // If snapshot already applied, just start WS
    if (hasData) {
      if (enableSubscription && _wsSub == null) {
        unawaited(_startSubscription(service));
      }
      return;
    }

    // Otherwise fetch snapshot
    unawaited(loadAndSubscribe());
  }

  // ---------------------------------------------------------------------------
  // Snapshot + reload logic
  // ---------------------------------------------------------------------------

  /// Apply an externally-fetched snapshot.
  ///
  /// Used during app bootstrap when config may be fetched
  /// before provider start().
  void applySnapshot(ConfigModel cfg) {
    _nonce++; // invalidate in-flight async ops
    _config = cfg;
    _lastError = null;
    _isLoading = false;
    notifyListeners();

    final service = _service;
    if (_started && enableSubscription && service != null) {
      unawaited(_startSubscription(service));
    }
  }

  /// Force a full reload:
  /// - Fetch snapshot over HTTP
  /// - Restart WebSocket subscription
  Future<void> reload() => loadAndSubscribe(force: true);

  /// Load snapshot and optionally subscribe.
  ///
  /// Uses `_nonce` to prevent stale async responses
  /// from overwriting newer state.
  Future<void> loadAndSubscribe({bool force = false}) async {
    final service = _service;
    if (service == null) return;

    // Skip reload if already loaded unless forced
    if (!force && _config != null && !_isLoading) {
      if (enableSubscription && _wsSub == null) {
        unawaited(_startSubscription(service));
      }
      return;
    }

    final nonce = ++_nonce;

    await _wsSub?.cancel();
    _wsSub = null;

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cfg = await service.fetchConfig();
      if (nonce != _nonce) return;

      _config = cfg;
      _isLoading = false;
      _lastError = null;
      notifyListeners();

      if (enableSubscription) {
        unawaited(_startSubscription(service));
      }
    } catch (e) {
      if (nonce != _nonce) return;
      _config = null;
      _isLoading = false;
      _lastError = e;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // WebSocket subscription handling
  // ---------------------------------------------------------------------------

  /// Start or restart the WebSocket subscription.
  ///
  /// This keeps config in sync with on-chain updates.
  Future<void> _startSubscription(ConfigService service) async {
    if (!identical(_service, service)) return;

    await _wsSub?.cancel();
    _wsSub = null;

    final nonce = _nonce;

    try {
      final stream = await service.subscribeConfig();
      if (nonce != _nonce) return;
      if (!identical(_service, service)) return;

      _wsSub = stream.listen(
        (cfg) {
          if (nonce != _nonce) return;
          _config = cfg;
          _lastError = null;
          notifyListeners();
        },
        onError: (e) {
          if (nonce != _nonce) return;
          _lastError = e;
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (nonce != _nonce) return;
      _lastError = e;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}
