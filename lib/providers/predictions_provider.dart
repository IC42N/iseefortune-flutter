import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/constants/program_id.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/services/predictions_service.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

/// PredictionsProvider
/// ---------------------------------------------------------------------------
/// Owns the "live prediction feed" for the CURRENT game epoch + tier.
///
/// What it does:
/// 1) Watches TierProvider + LiveFeedProvider
/// 2) When (epoch,tier) changes, it "rebinds":
///    - clears local data
///    - hydrates initial predictions via RPC
///    - starts a websocket subscription for live updates
///
/// What it stores:
/// - `_byPubkey`: map from Prediction ACCOUNT pubkey -> PredictionModel
/// - `_orderedPubkeys`: ordered list (newest first) of prediction account pubkeys
///
/// Important:
/// - The map key is the *prediction account pubkey*, NOT the player's wallet pubkey.
///   So "my prediction" requires scanning models for `model.player == myWallet`.
class PredictionsProvider extends ChangeNotifier {
  PredictionsProvider({this.enableSubscription = true, this.maxRecent = 200});

  /// If false: provider will hydrate and stop (no websocket),
  /// or in your current implementation it simply stops and marks not loading.
  final bool enableSubscription;

  /// Upper bound to prevent unbounded memory growth.
  /// You only keep the newest N predictions in the UI list.
  final int maxRecent;

  // ---------------------------------------------------------------------------
  // Dependencies (injected via ProxyProvider-safe attach methods)
  // ---------------------------------------------------------------------------

  TierProvider? _tier;
  LiveFeedProvider? _live;
  PredictionsService? _service;

  /// Stored listeners so we can remove them on re-attach/dispose.
  VoidCallback? _tierListener;
  VoidCallback? _liveListener;

  // ---------------------------------------------------------------------------
  // Lifecycle / binding flags
  // ---------------------------------------------------------------------------

  /// You explicitly start the provider. Before start(), it won't bind.
  bool _started = false;

  /// True while doing initial RPC hydration for the current (epoch,tier).
  bool _isLoading = false;

  /// Most recent error (RPC or websocket error).
  Object? _lastError;

  /// The "current context" this provider is bound to.
  /// If epoch or tier changes, we rebind and reset.
  BigInt? _activeGameEpoch;
  int? _activeTier;

  // ---------------------------------------------------------------------------
  // Data storage
  // ---------------------------------------------------------------------------

  /// Keyed by *prediction account pubkey*, not player pubkey.
  final Map<String, PredictionModel> _byPubkey = {};

  /// Newest first. Stores the keys for `_byPubkey` in sorted order.
  final List<String> _orderedPubkeys = [];

  /// Fast lookup for "my prediction" by player wallet pubkey.
  final Map<String, PredictionModel> _byPlayer = {};

  /// Current websocket subscription (if enabled).
  StreamSubscription<PredictionAccountUpdate>? _sub;

  /// "Generation counter" to safely ignore stale async work.
  ///
  /// Why this exists:
  /// - You might start a bind for (epoch A),
  /// - then quickly switch to (epoch B),
  /// - and the old RPC call returns late.
  ///
  /// This `_nonce` lets you discard any updates from the old bind.
  int _nonce = 0;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  BigInt? get activeGameEpoch => _activeGameEpoch;
  int? get activeTier => _activeTier;

  bool get hasData => _orderedPubkeys.isNotEmpty;

  /// Convenience: list of models newest-first (no pubkey).
  /// NOTE: This rebuilds a new list each call (fine for small size).
  List<PredictionModel> get recentPredictions =>
      List<PredictionModel>.unmodifiable(_orderedPubkeys.map((k) => _byPubkey[k]!));

  /// Convenience: list of entries newest-first (includes prediction account pubkey).
  List<MapEntry<String, PredictionModel>> get recentEntries =>
      List<MapEntry<String, PredictionModel>>.unmodifiable(
        _orderedPubkeys.map((k) => MapEntry(k, _byPubkey[k]!)),
      );

  /// How many unique prediction accounts we currently hold.
  int get streamedPredictionCount => _byPubkey.length;

  // Helper index to find "my prediction" by player wallet pubkey.
  void _indexByPlayer(PredictionModel p) {
    final player = p.player;
    if (player.isEmpty) return;

    final existing = _byPlayer[player];
    if (existing == null || p.lastActivityTs > existing.lastActivityTs) {
      _byPlayer[player] = p;
    }
  }

  void _rebuildPlayerIndex() {
    _byPlayer.clear();
    for (final k in _orderedPubkeys) {
      final p = _byPubkey[k];
      if (p != null) _indexByPlayer(p);
    }
  }

  // ---------------------------------------------------------------------------
  // Attach APIs (ProxyProvider-safe)
  // ---------------------------------------------------------------------------
  //
  // These let you use ProxyProvider without constructing this provider
  // with dependencies directly in the constructor.

  void attachTier(TierProvider tier) {
    // If it's the same instance, nothing to do.
    if (identical(_tier, tier)) return;

    // Detach previous listener if we were previously attached.
    if (_tier != null && _tierListener != null) {
      _tier!.removeListener(_tierListener!);
    }
    _tier = tier;

    // When tier changes, attempt a rebind (if started).
    _tierListener = () {
      if (!_started) return;
      _maybeRebind();
    };
    _tier!.addListener(_tierListener!);

    // If we're already started, bind immediately.
    if (_started) _maybeRebind();
  }

  void attachLiveFeed(LiveFeedProvider live) {
    if (identical(_live, live)) return;

    if (_live != null && _liveListener != null) {
      _live!.removeListener(_liveListener!);
    }
    _live = live;

    // When live feed changes, attempt rebind (if started).
    _liveListener = () {
      if (!_started) return;
      _maybeRebind();
    };
    _live!.addListener(_liveListener!);

    if (_started) _maybeRebind();
  }

  void attachService(PredictionsService service) {
    // No listeners here, just swap the reference.
    if (identical(_service, service)) return;
    _service = service;

    if (_started) _maybeRebind();
  }

  // ---------------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------------

  /// Start the provider's binding lifecycle.
  /// After calling start(), it will bind as soon as dependencies are ready.
  void start() {
    if (_started) return;
    _started = true;
    _maybeRebind();
  }

  /// Stop streaming. Increments nonce so late callbacks are ignored.
  Future<void> stop() async {
    _started = false;

    // invalidate any in-flight binds
    _nonce++;

    await _sub?.cancel();
    _sub = null;
  }

  // ---------------------------------------------------------------------------
  // Binding logic
  // ---------------------------------------------------------------------------

  /// Checks if dependencies are ready + (epoch,tier) changed.
  /// If so, clears state and binds to the new epoch/tier.
  void _maybeRebind() {
    final svc = _service;
    final tierProvider = _tier;
    final live = _live;

    // Must have all deps.
    if (svc == null || tierProvider == null || live == null) return;

    // Tier provider must be ready (ex: loaded config).
    if (!tierProvider.isReady) return;

    // Live feed must have data so we can know current game epoch.
    if (!live.hasData) return;

    final nextTier = tierProvider.tier;

    // CRITICAL:
    // You bind predictions to "firstEpochInChain" (gameEpoch),
    // not the current "liveFeed.epoch".
    // This means: predictions are grouped per game epoch chain boundary.
    final nextGameEpoch = live.liveFeed!.firstEpochInChain;

    // Only rebind if context actually changed.
    final needsSwitch = _activeTier != nextTier || _activeGameEpoch != nextGameEpoch;
    if (!needsSwitch) return;

    icLogger.i('[PredictionsProvider] bind gameEpoch=$nextGameEpoch tier=$nextTier');

    _activeTier = nextTier;
    _activeGameEpoch = nextGameEpoch;

    // Reset all state for new epoch/tier.
    _nonce++; // invalidate old async callbacks
    _byPubkey.clear();
    _byPlayer.clear();
    _orderedPubkeys.clear();

    _lastError = null;
    _isLoading = true;

    // Tell UI: "we are loading for new epoch/tier"
    notifyListeners();

    // Bind in background (do not await)
    unawaited(_bind(gameEpoch: nextGameEpoch, tier: nextTier, service: svc));
  }

  /// Performs the actual binding:
  /// 1) cancels old websocket stream
  /// 2) hydrates via RPC
  /// 3) subscribes via WS and applies updates in real-time
  Future<void> _bind({
    required BigInt gameEpoch,
    required int tier,
    required PredictionsService service,
  }) async {
    // Capture the current generation so we can ignore late returns.
    final int bindNonce = _nonce;

    // Cancel old stream first so we don't mix contexts.
    await _sub?.cancel();
    _sub = null;

    try {
      // ---------------------------------------------------------------------
      // 1) INITIAL HYDRATION (RPC)
      // ---------------------------------------------------------------------
      // We want existing predictions to appear immediately (even before WS updates).
      icLogger.i('[PredictionsProvider] hydrate start epoch=$gameEpoch tier=$tier');

      final initial = await service.fetchPredictionsForGameEpochTier(
        programId: programPubkey.toBase58(),
        gameEpoch: gameEpoch,
        tier: tier,
      );

      // If we switched contexts while awaiting, ignore this result.
      if (bindNonce != _nonce) return;
      if (_activeTier != tier) return;
      if (_activeGameEpoch != gameEpoch) return;

      // Sort newest first using lastActivityTs.
      initial.sort((a, b) => b.value.lastActivityTs.compareTo(a.value.lastActivityTs));

      // Rebuild the store.
      _byPubkey.clear();
      _orderedPubkeys.clear();

      for (final e in initial) {
        final predPda = e.key;
        final pred = e.value;

        _byPubkey[predPda] = pred;
        _orderedPubkeys.add(predPda);

        _indexByPlayer(pred);
      }

      // Prevent unbounded list growth.
      _trimToMax();

      icLogger.i('[PredictionsProvider] hydrate done count=${_orderedPubkeys.length}');

      // Hydrated data is now ready for the UI.
      _isLoading = false;
      _lastError = null;
      notifyListeners();

      // If subscription is disabled, we stop here.
      // (In your current behavior, this means "no data stream".)
      if (!enableSubscription) {
        return;
      }

      // ---------------------------------------------------------------------
      // 2) LIVE STREAM (WS)
      // ---------------------------------------------------------------------
      // After hydration, we keep the list "alive" with incoming updates.
      icLogger.i('[PredictionsProvider] ws subscribe start epoch=$gameEpoch tier=$tier');

      _sub = service
          .subscribePredictionsForGameEpochTier(
            programId: programPubkey.toBase58(),
            gameEpoch: gameEpoch,
            tier: tier,
            commitment: 'confirmed',
          )
          .listen(
            (update) {
              // Ignore if context changed.
              if (bindNonce != _nonce) return;
              if (_activeTier != tier) return;
              if (_activeGameEpoch != gameEpoch) return;

              icLogger.i(
                '[PredictionsProvider] ws update pubkey=${update.pubkey} player=${update.prediction.player} ts=${update.prediction.lastActivityTs}',
              );

              // Apply update into local store + ordering.
              _upsert(update.pubkey, update.prediction);
            },
            onError: (e) {
              if (bindNonce != _nonce) return;

              icLogger.w('[PredictionsProvider] WS error: $e');
              _lastError = e;
              notifyListeners();

              // Self-heal: try to resubscribe shortly
              Future.delayed(const Duration(seconds: 1), () {
                if (!_started) return;
                if (bindNonce != _nonce) return;
                unawaited(forceReload());
              });
            },
            cancelOnError: false,
            onDone: () {
              icLogger.w('[PredictionsProvider] WS done ❌ (stream closed)');
            },
          );

      icLogger.i('[PredictionsProvider] ws subscribed epoch=$gameEpoch tier=$tier');
    } catch (e) {
      // RPC or subscription setup failure
      if (bindNonce != _nonce) return;

      icLogger.e('[PredictionsProvider] bind failed: $e');
      _isLoading = false;
      _lastError = e;
      notifyListeners();
    }
  }

  /// Insert or update a prediction (by prediction account pubkey),
  /// and keep `_orderedPubkeys` newest-first.
  void _upsert(String pubkey, PredictionModel prediction) {
    final existing = _byPubkey[pubkey];

    // If the incoming update is not newer (based on lastActivityTs),
    // we treat it as "maybe same timestamp but content changed".
    //
    // Why:
    // - Some updates might come in with same timestamp but changed fields
    // - Or you can get duplicate updates from WS/RPC
    if (existing != null && prediction.lastActivityTs <= existing.lastActivityTs) {
      final changed = prediction.toJson().toString() != existing.toJson().toString();
      _byPubkey[pubkey] = prediction;

      // Only notify if actual content changed.
      if (changed) notifyListeners();
      return;
    }

    // If truly new or newer, update map.
    final isNew = existing == null;
    _byPubkey[pubkey] = prediction;
    _indexByPlayer(prediction);

    // Maintain newest-first ordering:
    // - New prediction => insert at front
    // - Existing prediction updated => move to front
    if (isNew) {
      _orderedPubkeys.insert(0, pubkey);
    } else {
      _orderedPubkeys.remove(pubkey);
      _orderedPubkeys.insert(0, pubkey);
    }

    _trimToMax();
    notifyListeners();
  }

  /// Ensures we only store the newest `maxRecent` predictions.
  void _trimToMax() {
    if (_orderedPubkeys.length <= maxRecent) return;

    final overflow = _orderedPubkeys.length - maxRecent;
    for (var i = 0; i < overflow; i++) {
      final tailKey = _orderedPubkeys.removeLast();
      _byPubkey.remove(tailKey);
    }

    // We removed items, so index might now point at removed items.
    _rebuildPlayerIndex();
  }

  // ---------------------------------------------------------------------------
  // Manual controls
  // ---------------------------------------------------------------------------

  /// Forces a full re-hydration + re-subscribe for current epoch/tier.
  /// Useful if you think you're out of sync.
  Future<void> forceReload() async {
    final svc = _service;
    final tier = _activeTier;
    final epoch = _activeGameEpoch;
    if (svc == null || tier == null || epoch == null) return;

    icLogger.i('[PredictionsProvider] forceReload epoch=$epoch tier=$tier');

    // invalidate old callbacks
    _nonce++;

    // reset data
    _byPubkey.clear();
    _byPlayer.clear();
    _orderedPubkeys.clear();
    _lastError = null;
    _isLoading = true;
    notifyListeners();

    // bind again
    await _bind(gameEpoch: epoch, tier: tier, service: svc);
  }

  Future<void> refresh() => forceReload();

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    if (_tier != null && _tierListener != null) _tier!.removeListener(_tierListener!);
    if (_live != null && _liveListener != null) _live!.removeListener(_liveListener!);
    _sub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // My prediction model
  // ---------------------------------------------------------------------------

  /// Returns the latest prediction for this active epoch+tier for a given PLAYER wallet pubkey.
  ///
  /// NOTE:
  /// - `_byPubkey` keys are prediction account pubkeys.
  /// - We search the values (PredictionModel) for `p.player == playerWalletPubkey`.
  ///
  /// This is fast enough at maxRecent=200.
  ///
  /// If you ever scale to 5k+ predictions, add an index:
  // ignore: unintended_html_in_doc_comment
  /// Map<String /*player*/, String /*predictionPda*/> and update it in _upsert.
  PredictionModel? myPredictionForPlayer(String playerWalletPubkey) {
    return _byPlayer[playerWalletPubkey];
  }
}
