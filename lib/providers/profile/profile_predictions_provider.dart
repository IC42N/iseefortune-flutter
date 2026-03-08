import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/models/profile/profile_prediction_context.dart';
import 'package:iseefortune_flutter/models/profile/profile_prediction_row_mapper.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_pda_provider.dart';
import 'package:iseefortune_flutter/services/profile/player_predicitons_service.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

/// ----------------------------------------------------------------------------
/// PlayerPredictionsProvider
/// ----------------------------------------------------------------------------
/// What this provider “owns”:
/// - A *paged window* of the player’s most recent prediction PDAs (keys)
/// - The decoded PredictionModel for those PDAs
/// - A set of WebSocket subscriptions for predictions that are still “mutable”
///
/// IMPORTANT CONCEPT:
/// This provider does NOT discover predictions out of thin air.
/// It learns what predictions exist from the Profile PDA (ring buffer / list).
/// Then it fetches those prediction accounts and optionally subscribes to them.
///
/// Data flow (high level):
///   ProfilePdaProvider changes
///      -> PlayerPredictionsProvider.refresh()
///          -> reads recent prediction keys from profile
///          -> fetches those prediction accounts (chunked)
///          -> determines which are mutable
///          -> subscribes only to the mutable ones
///
/// Live updates:
///   LiveFeedProvider epoch changes
///      -> recompute “mutable set”
///      -> subscribe/unsubscribe accordingly
///
/// WebSocket subscriptions here only update *existing* predictions that are
/// already known (already in _orderedKeys). They do not add new keys.
///
/// ----------------------------------------------------------------------------
class PlayerPredictionsProvider extends ChangeNotifier {
  PlayerPredictionsProvider({
    required PlayerPredictionsService service,
    required ProfilePdaProvider profilePda,
    this.pageSize = 20,
    this.maxItems = 40,
  }) : _service = service,
       _profilePda = profilePda;

  // ---------------------------------------------------------------------------
  // Dependencies (other layers we rely on)
  // ---------------------------------------------------------------------------

  /// Handles:
  /// - RPC fetching prediction PDAs in chunks
  /// - WebSocket account subscription to a specific prediction PDA
  /// - “mutability” classification logic (pickMutableKeys)
  final PlayerPredictionsService _service;

  /// Provides:
  /// - The Profile PDA decode (player address + list of recent prediction PDAs)
  /// - A notify mechanism when that profile changes (new prediction key added)
  final ProfilePdaProvider _profilePda;

  /// Pagination controls:
  /// - pageSize: how many to fetch per chunk
  /// - maxItems: maximum list size you’ll ever show
  final int pageSize;
  final int maxItems;

  /// Listener registration handle for ProfilePdaProvider changes.
  VoidCallback? _profileListener;

  /// Once disposed, we must avoid notifyListeners and cancel subscriptions.
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // UI State (loading + errors + pagination)
  // ---------------------------------------------------------------------------

  /// True while refresh() is actively fetching.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Stores the last refresh error (if any).
  Object? _lastError;
  Object? get lastError => _lastError;

  /// “How many items do we currently show?”
  /// (This grows when you loadMore())
  int _limit = 20;
  int get limit => _limit;

  /// Row overrides for UI (e.g. show optimistic/pending state).
  bool hasOverride(String pda) => _rowOverrides.containsKey(pda);

  // ---------------------------------------------------------------------------
  // Epoch handling (fed by LiveFeedProvider)
  // ---------------------------------------------------------------------------

  /// The “current game epoch” used to decide mutability.
  /// If LiveFeed isn’t ready, returns 0.
  BigInt _currentGameEpochOrZero() => _live?.currentGameEpochOrZero ?? BigInt.zero;

  // ---------------------------------------------------------------------------
  // Prediction Data (cached in memory)
  // ---------------------------------------------------------------------------

  /// Decoded prediction accounts keyed by prediction PDA pubkey string.
  final Map<String, PredictionModel> _byPubkey = {};

  /// External read-only access.
  Map<String, PredictionModel> get byPubkey => Map.unmodifiable(_byPubkey);

  /// The ordered list of prediction PDAs for rendering.
  /// This order comes from the Profile PDA’s “recent bets” ring buffer.
  List<String> _orderedKeys = const [];
  List<String> get orderedKeys => _orderedKeys;

  /// Convenient list of decoded models in display order.
  /// Missing models are skipped (might happen during progressive fetch).
  List<PredictionModel> get orderedModels =>
      _orderedKeys.map((k) => _byPubkey[k]).whereType<PredictionModel>().toList();

  /// Converts PredictionModel -> UI row VM.
  /// If an override exists for a PDA, it wins over the derived base row.
  List<ProfilePredictionRowVM> buildRows(ProfilePredictionContext ctx) {
    return _orderedKeys
        .map((pda) {
          final m = _byPubkey[pda];
          if (m == null) return null;

          final base = mapPredictionModelToProfileRow(m: m, predictionPda: pda, ctx: ctx);
          return _rowOverrides[pda] ?? base;
        })
        .whereType<ProfilePredictionRowVM>()
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Live Subscriptions (WebSocket account listeners)
  // ---------------------------------------------------------------------------

  /// Active subscriptions keyed by prediction PDA.
  /// These are only for “mutable” predictions.
  final Map<String, StreamSubscription<PredictionModel>> _liveSubs = {};

  /// Token to cancel outdated refresh calls.
  /// Every refresh increments this; async callbacks check it.
  int _refreshToken = 0;

  /// Prevent notifyListeners after dispose.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LiveFeed wiring (epoch change notifications)
  // ---------------------------------------------------------------------------

  LiveFeedProvider? _live;
  VoidCallback? _liveListener;
  BigInt _lastEpoch = BigInt.zero;

  /// attachLiveFeed is called by a ProxyProvider in main.dart.
  /// It makes this provider react when the “current game epoch” changes.
  ///
  /// Key reason:
  /// - Mutability depends on epoch (e.g. “current epoch” predictions stay mutable)
  /// - So when epoch changes, we recompute which predictions need subscriptions.
  void attachLiveFeed(LiveFeedProvider live) {
    if (identical(_live, live)) return;

    _detachLiveFeed();
    _live = live;

    _liveListener = () {
      final next = live.currentGameEpochOrZero;

      // Ignore duplicate updates.
      if (next == _lastEpoch) return;

      _lastEpoch = next;
      _onGameEpochChanged(next);
    };

    live.addListener(_liveListener!);

    // Run once immediately.
    // Important: LiveFeed may already have an epoch set before attach happens.
    _lastEpoch = live.currentGameEpochOrZero;
    _onGameEpochChanged(_lastEpoch);
  }

  /// Remove live feed listener safely.
  void _detachLiveFeed() {
    final l = _liveListener;
    final live = _live;
    if (live != null && l != null) {
      live.removeListener(l);
    }
    _liveListener = null;
    _live = null;
  }

  /// Called whenever the game epoch changes.
  /// It only affects which predictions we *stay subscribed to*.
  ///
  /// It does NOT fetch new keys from profile; it only updates subscriptions
  /// for already-known predictions in _orderedKeys/_byPubkey.
  void _onGameEpochChanged(BigInt nextEpoch) {
    if (nextEpoch == BigInt.zero) {
      // If we don’t know the epoch, we can’t safely decide mutability.
      // So we cancel everything to avoid waste/incorrect “live” state.
      _reconcileLiveSubs(targetKeys: const []);
      return;
    }

    // If we haven’t loaded any predictions yet, nothing to do.
    if (_orderedKeys.isEmpty || _byPubkey.isEmpty) return;

    // Recompute which keys should remain subscribed.
    final target = _pickMutable(_orderedKeys);
    _reconcileLiveSubs(targetKeys: target);
  }

  // ---------------------------------------------------------------------------
  // Profile wiring (wallet-aware list of prediction keys)
  // ---------------------------------------------------------------------------

  /// attach() is called when the provider is created / wallet session ready.
  /// It listens to ProfilePdaProvider changes.
  ///
  /// This is the path that should cause “new prediction appears in list”
  /// IF ProfilePdaProvider updates its ring buffer and notifies listeners.
  void attach() {
    _profileListener ??= _onProfileChanged;
    _profilePda.addListener(_profileListener!);

    // Run once immediately for initial load (auto-connect).
    _onProfileChanged();
  }

  /// detach() removes listeners and cancels WS.
  /// Used during dispose or when wallet disconnects.
  void detach() {
    if (_profileListener != null) {
      _profilePda.removeListener(_profileListener!);
      _profileListener = null;
    }

    _detachLiveFeed();
    _cancelAllLiveSubs();
  }

  @override
  void dispose() {
    _disposed = true;
    detach();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // User Actions (pagination)
  // ---------------------------------------------------------------------------

  bool get canLoadMore => _limit < maxItems;

  /// Increase how many predictions we show and refetch.
  Future<void> loadMore() async {
    if (!canLoadMore) return;

    _limit = (_limit + pageSize).clamp(0, maxItems);
    _safeNotify();
    await refresh(force: true);
  }

  // ---------------------------------------------------------------------------
  // Core refresh() (pull data from ProfilePDA -> fetch prediction PDAs)
  // ---------------------------------------------------------------------------

  /// refresh() is the “source of truth sync”.
  ///
  /// Steps:
  /// 1) Read the Profile PDA from ProfilePdaProvider.
  /// 2) Extract recent prediction keys (ring buffer list).
  /// 3) Take up to _limit keys (pagination).
  /// 4) Progressive chunk fetch those prediction accounts via RPC.
  /// 5) After each chunk:
  ///      - merge decoded models into _byPubkey
  ///      - notify UI
  ///      - recompute subscriptions for mutable predictions
  ///
  /// NOTE:
  /// This is the only place in THIS file that can add *new PDAs* to _orderedKeys.
  /// And _orderedKeys is what drives your list rendering.
  Future<void> refresh({bool force = false}) async {
    final profile = _profilePda.profile;
    final pubkey = profile?.player;

    // No wallet / profile means no predictions.
    if (pubkey == null || pubkey.isEmpty) {
      _resetState();
      return;
    }

    icLogger.i('[Profile Predictions] refresh() start limit=$_limit player=${_profilePda.profile?.player}');

    // The profile stores a list of prediction PDAs (most recent first).
    final keysAll = profile!.recentBetsMostRecentFirst;

    // Only show up to the UI limit.
    final keys = keysAll.take(_limit).toList(growable: false);

    icLogger.i('[Profile Predictions] keysAll=${keysAll.length} keys(take limit)=${keys.length}');
    if (keys.isNotEmpty) icLogger.i('[Profile Predictions] firstKey=${keys.first}');

    // If there are no keys, clear list and cancel subscriptions.
    if (keys.isEmpty) {
      _resetPredictionsOnly();
      _reconcileLiveSubs(targetKeys: const []);
      return;
    }

    // If keys are unchanged and we already have all models decoded, we can skip.
    // We still re-evaluate subscriptions (epoch might have changed).
    if (!force && listEquals(keys, _orderedKeys) && _byPubkey.length >= keys.length) {
      _reconcileLiveSubs(targetKeys: _pickMutable(keys));
      return;
    }

    // New refresh token invalidates older inflight async callbacks.
    final token = ++_refreshToken;

    _isLoading = true;
    _lastError = null;

    // This is where the UI list “set of keys” updates.
    // If profile has added a new prediction PDA, it will appear here.
    _orderedKeys = keys;
    _safeNotify();

    // Remove decoded models that are no longer in the current key window.
    _byPubkey.removeWhere((k, _) => !keys.contains(k));

    try {
      // Fetch prediction accounts progressively to show list quickly.
      await _service.fetchPredictionsChunkedEach(
        keys,
        chunkSize: pageSize,
        commitment: 'confirmed',
        tag: 'playerPredictions',
        onChunk: (chunk) {
          icLogger.i('[Profile Predictions] onChunk accountsDecoded=${chunk.length}');

          // If provider disposed or a newer refresh started, ignore.
          if (_disposed || token != _refreshToken) return;

          // Merge decoded accounts and update UI.
          _byPubkey.addAll(chunk);
          _safeNotify();

          // After each chunk, update which PDAs are WS subscribed.
          final target = _pickMutable(_orderedKeys);
          _reconcileLiveSubs(targetKeys: target);
        },
      );

      // If a newer refresh started, stop.
      if (token != _refreshToken) return;

      _isLoading = false;
      _safeNotify();

      // Final subscription reconciliation after full fetch.
      final target = _pickMutable(_orderedKeys);
      _reconcileLiveSubs(targetKeys: target);
    } catch (e) {
      if (token != _refreshToken) return;

      _lastError = e;
      _isLoading = false;
      _safeNotify();
    }
  }

  // ---------------------------------------------------------------------------
  // Profile change handling
  // ---------------------------------------------------------------------------

  /// Called whenever ProfilePdaProvider notifies.
  /// Usually happens on:
  /// - wallet connect
  /// - profile loaded
  /// - profile updated (e.g. new prediction PDA appended to ring buffer)
  ///
  /// This is the gateway for “new prediction appears in list automatically”.
  void _onProfileChanged() {
    icLogger.i(
      '[Profile Predictions] profile changed. '
      'isLoading=${_profilePda.isLoading} '
      'hasLoadedOnce=${_profilePda.hasLoadedOnce} '
      'profile=${_profilePda.profile?.player}',
    );

    if (_profilePda.isLoading) return;

    final p = _profilePda.profile;
    if (p == null) {
      _resetState();
      return;
    }

    // Trigger a refresh to pull latest prediction key list from profile.
    unawaited(refresh());
  }

  // ---------------------------------------------------------------------------
  // Reset logic
  // ---------------------------------------------------------------------------

  void _resetState() {
    _refreshToken++; // cancel inflight
    _isLoading = false;
    _lastError = null;
    _limit = pageSize;
    _orderedKeys = const [];
    _byPubkey.clear();
    _rowOverrides.clear();
    _cancelAllLiveSubs();
    _safeNotify();
  }

  void _resetPredictionsOnly() {
    _refreshToken++;
    _isLoading = false;
    _lastError = null;
    _orderedKeys = const [];
    _byPubkey.clear();
    _rowOverrides.clear();
    _cancelAllLiveSubs();
    _safeNotify();
  }

  // ---------------------------------------------------------------------------
  // Subscription logic (ONLY for existing prediction PDAs)
  // ---------------------------------------------------------------------------

  /// Compute which prediction PDAs should have WS subscriptions.
  ///
  /// Current behavior: delegates to service with only currentEpoch.
  /// If your game spans multiple epochs, this is likely too narrow.
  List<String> _pickMutable(List<String> orderedKeys) {
    final current = _currentGameEpochOrZero();
    if (current == BigInt.zero) return const [];

    // Only consider models we’ve already decoded.
    final present = <String, PredictionModel>{};
    for (final k in orderedKeys) {
      final m = _byPubkey[k];
      if (m != null) present[k] = m;
    }

    return _service.pickMutableKeysForActiveGame(present, activeGameEpoch: current);
  }

  /// Reconcile subscriptions:
  /// - cancel subs for keys not in target
  /// - add subs for keys newly in target
  ///
  /// These subscriptions update _byPubkey when account data changes.
  void _reconcileLiveSubs({required List<String> targetKeys}) {
    final target = targetKeys.toSet();

    // Cancel subscriptions we no longer want.
    final toCancel = _liveSubs.keys.where((k) => !target.contains(k)).toList();
    for (final k in toCancel) {
      _liveSubs.remove(k)?.cancel();
    }

    // Create subscriptions we are missing.
    for (final k in target) {
      if (_liveSubs.containsKey(k)) continue;

      icLogger.i('[PlayerPredictionsProvider] subscribe prediction=$k');

      // This is the WS stream for ONE prediction PDA.
      // It pushes updated PredictionModel values when the account changes.
      final sub = _service
          .subscribePrediction(k, commitment: 'confirmed')
          .listen(
            (m) {
              if (_disposed) return;
              // Update in-memory cache and redraw UI.
              _byPubkey[k] = m;
              _safeNotify();
            },
            onError: (e) {
              if (_disposed) return;
              icLogger.w('[PlayerPredictionsProvider] sub error prediction=$k err=$e');
            },
          );

      _liveSubs[k] = sub;
    }
  }

  /// Cancel all active prediction subscriptions.
  void _cancelAllLiveSubs() {
    for (final s in _liveSubs.values) {
      s.cancel();
    }
    _liveSubs.clear();
  }

  // ---------------------------------------------------------------------------
  // Row overrides (UI-only)
  // ---------------------------------------------------------------------------

  final Map<String, ProfilePredictionRowVM> _rowOverrides = {};
  ProfilePredictionRowVM? overrideFor(String pda) => _rowOverrides[pda];

  void upsertRowOverrideForPda(String pda, ProfilePredictionRowVM row) {
    _rowOverrides[pda] = row;
    _safeNotify();
  }

  void clearOverride(String pda) {
    if (_rowOverrides.remove(pda) != null) _safeNotify();
  }

  /// Returns the Prediction PDA for the current game chain (gameEpoch),
  /// or null if the player didn't play this game.
  String? findPredictionPdaForGameEpoch({
    required BigInt gameEpoch, // PredictionModel.gameEpoch
    required int tier,
    String? playerPubkey, // optional safety
  }) {
    if (gameEpoch == BigInt.zero) return null;

    for (final pda in _orderedKeys) {
      final m = _byPubkey[pda];
      if (m == null) continue;

      if (m.gameEpoch != gameEpoch) continue;
      if (m.tier != tier) continue;

      if (playerPubkey != null && m.player != playerPubkey) continue;

      return pda;
    }

    return null;
  }

  bool didPlayGameEpoch({required BigInt gameEpoch, required int tier, String? playerPubkey}) =>
      findPredictionPdaForGameEpoch(gameEpoch: gameEpoch, tier: tier, playerPubkey: playerPubkey) != null;
}
