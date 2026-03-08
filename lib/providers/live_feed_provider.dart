import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/models/live_feed_model.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/services/live_feed_service.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

/// Small in-memory cache entry for a tier.
class _LiveFeedCacheEntry {
  _LiveFeedCacheEntry({required this.model, required this.updatedAt});

  final LiveFeedModel model;
  final DateTime updatedAt;
}

/// LiveFeedProvider (attach-style, bootstrap-gated)
/// ---------------------------------------------------------------------------
/// Key behavior:
/// - Provider can be constructed + dependencies attached anytime
/// - It does **nothing network-related** until `start()` is called
/// - AppBootstrapper can:
///   1) load TierProvider
///   2) try BootSnapshotService.getMultipleAccounts
///   3) call applySnapshot(...)
///   4) call start() to begin WS + fallback HTTP fetch if needed
class LiveFeedProvider extends ChangeNotifier {
  LiveFeedProvider();

  // ---------------------------------------------------------------------------
  // Dependencies (attached after construction)
  // ---------------------------------------------------------------------------

  TierProvider? _tier;
  VoidCallback? _tierListener;

  LiveFeedService? _service;

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  int? _activeTier;
  bool _isLoading = false;
  LiveFeedModel? _liveFeed;
  Object? _lastError;

  int? get activeTier => _activeTier;
  bool get isLoading => _isLoading;
  LiveFeedModel? get liveFeed => _liveFeed;
  Object? get lastError => _lastError;

  bool get hasData => _liveFeed != null;
  bool get isTierReady => _tier?.isReady ?? false;

  /// “Ready” for UI means we have a model and we’re not in initial load.
  bool get isReady => hasData && !_isLoading;

  // ---------------------------------------------------------------------------
  // In-memory cache (per tier)
  // ---------------------------------------------------------------------------

  static const Duration _cacheMaxAge = Duration(seconds: 3);
  static const bool _useCacheForInstantPaint = true;

  final Map<int, _LiveFeedCacheEntry> _cacheByTier = {};

  void _putCache(int tier, LiveFeedModel model) {
    _cacheByTier[tier] = _LiveFeedCacheEntry(model: model, updatedAt: DateTime.now());
  }

  LiveFeedModel? _getFreshCache(int tier) {
    final entry = _cacheByTier[tier];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.updatedAt);
    if (age > _cacheMaxAge) return null;

    return entry.model;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  StreamSubscription<LiveFeedModel>? _wsSub;

  /// Monotonic generation counter: any async callback must match this or be ignored.
  int _nonce = 0;

  /// Bootstrap gate: we do not fetch/subscribe until start() is called.
  bool _started = false;

  // ---------------------------------------------------------------------------
  // Attach APIs
  // ---------------------------------------------------------------------------

  void attachTier(TierProvider tierProvider) {
    if (identical(_tier, tierProvider)) return;

    if (_tier != null && _tierListener != null) {
      _tier!.removeListener(_tierListener!);
    }

    _tier = tierProvider;

    _tierListener = () {
      if (!_started) return;

      final t = _tier;
      if (t == null || !t.isReady) return;

      final nextTier = t.tier;
      if (nextTier == _activeTier) return;

      icLogger.i('[LiveFeedProvider] tier changed -> $nextTier');
      _handleTierChange(nextTier);
    };

    _tier!.addListener(_tierListener!);

    // If tier already ready and we’re started, react immediately.
    if (_started && _tier!.isReady) {
      _handleTierChange(_tier!.tier);
    }
  }

  void attachService(LiveFeedService service) {
    if (identical(_service, service)) return;
    _service = service;

    if (!_started) return;

    final tier = _resolveTier();
    if (tier == null) return;

    // If we already have data (boot snapshot or cached paint), don’t clear UI.
    // Just ensure WS is running.
    if (hasData) {
      unawaited(_restartWsForTier(tier, service));
      return;
    }

    // Otherwise do normal flow.
    _switchTier(tier);
  }

  // ---------------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------------

  /// Called once by AppBootstrapper after boot snapshot attempt.
  ///
  /// After this:
  /// - If snapshot already applied => starts WS only
  /// - Else => runs normal fetch+ws for resolved tier
  void start() {
    if (_started) return;
    _started = true;

    final tier = _resolveTier();
    if (tier == null) return;

    final service = _service;

    // If snapshot already present, just start WS.
    if (hasData && service != null) {
      unawaited(_restartWsForTier(tier, service));
      return;
    }

    // Otherwise, do normal load.
    _switchTier(tier);
  }

  int? _resolveTier() {
    // Prefer an explicitly active tier if we have one, else TierProvider if ready.
    final t = _activeTier;
    if (t != null) return t;

    final tierProvider = _tier;
    if (tierProvider != null && tierProvider.isReady) return tierProvider.tier;

    return null;
  }

  // ---------------------------------------------------------------------------
  // Tier switch handling
  // ---------------------------------------------------------------------------

  void _handleTierChange(int nextTier) {
    // We *want* AppBootstrapper to have a chance to applySnapshot first.
    // One microtask is enough; if snapshot didn’t arrive, we proceed normally.
    scheduleMicrotask(() {
      if (!_started) return;

      // If tier changed again, ignore.
      final currentTier = _tier?.isReady == true ? _tier!.tier : null;
      if (currentTier != null && currentTier != nextTier) return;

      _activeTier = nextTier;

      final svc = _service;

      // If boot snapshot already applied (or cache painted), don’t refetch.
      if (hasData && svc != null) {
        unawaited(_restartWsForTier(nextTier, svc));
        return;
      }

      _switchTier(nextTier);
    });
  }

  void _switchTier(int tier) {
    _activeTier = tier;

    // Cancel old WS
    _wsSub?.cancel();
    _wsSub = null;

    _lastError = null;

    // Optional instant paint from cache
    final cached = _useCacheForInstantPaint ? _getFreshCache(tier) : null;

    if (cached != null) {
      _liveFeed = cached;
      _isLoading = true; // “syncing”
    } else {
      _liveFeed = null;
      _isLoading = true;
    }

    notifyListeners();

    unawaited(_loadAndSubscribe(tier));
  }

  Future<void> _loadAndSubscribe(int tier) async {
    final service = _service;
    if (service == null) {
      icLogger.w('[LiveFeedProvider] _loadAndSubscribe skipped: service not attached');
      _isLoading = false;
      _lastError = StateError('LiveFeedService not attached');
      notifyListeners();
      return;
    }

    final nonce = ++_nonce;

    try {
      // 1) HTTP snapshot
      final snapshot = await service.fetchLiveFeed(tier);
      if (nonce != _nonce) return;
      if (_activeTier != tier) return;

      _liveFeed = snapshot;
      _putCache(tier, snapshot);
      _lastError = null;
      _isLoading = false;
      notifyListeners();

      // 2) WS subscription
      await _wsSub?.cancel();
      _wsSub = service
          .subscribeLiveFeed(tier)
          .listen(
            (model) {
              if (nonce != _nonce) return;
              if (_activeTier != tier) return;

              _liveFeed = model;
              _putCache(tier, model);
              _lastError = null;
              notifyListeners();
            },
            onError: (e) {
              if (nonce != _nonce) return;
              if (_activeTier != tier) return;

              icLogger.w('[LiveFeedProvider] WS error (tier=$tier): $e');
              _lastError = e;
              notifyListeners();
            },
            cancelOnError: false,
          );
    } catch (e) {
      if (nonce != _nonce) return;
      if (_activeTier != tier) return;

      icLogger.e('[LiveFeedProvider] load failed (tier=$tier): $e');
      _lastError = e;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Public: manual refresh
  // ---------------------------------------------------------------------------
  Future<void> refresh() async {
    final tier = _activeTier;
    final service = _service;
    if (tier == null || service == null) return;

    final nonce = ++_nonce;

    try {
      final model = await service.fetchLiveFeed(tier);
      if (nonce != _nonce) return;
      if (_activeTier != tier) return;

      _liveFeed = model;
      _putCache(tier, model);
      _lastError = null;
      notifyListeners();
    } catch (e) {
      if (nonce != _nonce) return;
      icLogger.w('[LiveFeedProvider] refresh failed (tier=$tier): $e');
      _lastError = e;
      notifyListeners();
    }
  }

  /// Force a full reload for the current tier:
  /// - HTTP snapshot fetch
  /// - restart WS subscription
  /// Force a full reload for the current tier:
  /// - HTTP snapshot fetch
  /// - restart WS subscription
  Future<void> forceReload({String commitment = 'confirmed'}) async {
    final tier = _resolveTier();
    final service = _service;

    if (tier == null || service == null) return;

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    // One generation counter for everything in this provider
    final nonce = ++_nonce;

    try {
      final snapshot = await service.fetchLiveFeed(tier, commitment: commitment);
      if (nonce != _nonce) return;
      if (_activeTier != tier) return;

      _liveFeed = snapshot;
      _putCache(tier, snapshot);

      _isLoading = false;
      _lastError = null;
      notifyListeners();

      // Restart WS for this tier (this will bump _nonce again internally)
      await _restartWsForTier(tier, service);
    } catch (e) {
      if (nonce != _nonce) return;
      if (_activeTier != tier) return;

      _isLoading = false;
      _lastError = e;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Public: apply boot snapshot
  // ---------------------------------------------------------------------------

  /// Apply decoded snapshot (from BootSnapshotService).
  /// Safe to call before start().
  void applySnapshot({required int tier, required LiveFeedModel model}) {
    // Invalidate any in-flight work
    _nonce++;

    _activeTier = tier;
    _liveFeed = model;
    _putCache(tier, model);

    _lastError = null;
    _isLoading = false;
    notifyListeners();

    final service = _service;
    if (_started && service != null) {
      unawaited(_restartWsForTier(tier, service));
    }
  }

  Future<void> _restartWsForTier(int tier, LiveFeedService service) async {
    if (!identical(_service, service)) return;

    final nonce = ++_nonce;

    await _wsSub?.cancel();
    _wsSub = null;

    try {
      _wsSub = service
          .subscribeLiveFeed(tier)
          .listen(
            (m) {
              if (nonce != _nonce) return;
              if (_activeTier != tier) return;

              _liveFeed = m;
              _putCache(tier, m);
              _lastError = null;
              notifyListeners();
            },
            onError: (e) {
              if (nonce != _nonce) return;
              if (_activeTier != tier) return;

              icLogger.w('[LiveFeedProvider] WS error (tier=$tier): $e');
              _lastError = e;
              notifyListeners();
            },
            cancelOnError: false,
          );
    } catch (e) {
      if (nonce != _nonce) return;
      if (_activeTier != tier) return;

      icLogger.w('[LiveFeedProvider] WS subscribe failed (tier=$tier): $e');
      _lastError = e;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    if (_tier != null && _tierListener != null) {
      _tier!.removeListener(_tierListener!);
    }
    _wsSub?.cancel();
    super.dispose();
  }
}

extension LiveFeedEpochX on LiveFeedProvider {
  /// Current game epoch for prediction mutability.
  /// Uses LiveFeed as source of truth.
  BigInt get currentGameEpochOrZero {
    final m = liveFeed;
    if (m == null) return BigInt.zero;
    return m.firstEpochInChain; // BigInt
  }

  bool get hasCurrentGameEpoch => liveFeed != null;
}
