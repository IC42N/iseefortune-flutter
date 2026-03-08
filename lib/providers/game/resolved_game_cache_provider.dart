import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_repo.dart';
import 'package:iseefortune_flutter/models/game/game_unified_model.dart';

@immutable
class ResolvedGameKey {
  const ResolvedGameKey(this.epoch, this.tier);
  final int epoch;
  final int tier;

  @override
  bool operator ==(Object other) => other is ResolvedGameKey && other.epoch == epoch && other.tier == tier;

  @override
  int get hashCode => Object.hash(epoch, tier);
}

/// ResolvedGameCacheProvider (in-flight dedupe only)
/// ---------------------------------------------------------------------------
/// Why this exists even though the repo already caches:
/// - Repo caches *completed* results.
/// - This provider dedupes *concurrent* requests for the same (epoch,tier),
///   so multiple accordion expands don't trigger duplicate network calls.
///
/// It does NOT store completed results long-term; it relies on the repo cache.
/// ---------------------------------------------------------------------------
class ResolvedGameCacheProvider extends ChangeNotifier {
  ResolvedGameCacheProvider({required ResolvedGameRepository repo}) : _repo = repo;

  ResolvedGameRepository _repo;

  // Only tracks in-flight requests. Completed results are cached in the repo.
  final _inflight = HashMap<ResolvedGameKey, Future<ResolvedGameHistoryModel>>();

  void attachRepo(ResolvedGameRepository repo) {
    if (identical(_repo, repo)) return;
    _repo = repo;
    _inflight.clear();
    notifyListeners();
  }

  /// Fetch resolved game for (epoch,tier), deduping concurrent calls.
  ///
  /// - If a request is already in-flight for this key, returns the same Future.
  /// - When the request completes (success or error), it is removed from _inflight.
  /// - Completed caching is handled by ResolvedGameRepository.
  Future<ResolvedGameHistoryModel> getOrFetch({required int epoch, required int tier}) {
    final key = ResolvedGameKey(epoch, tier);

    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final fut = _repo.getByEpoch(epoch: epoch, tier: tier).whenComplete(() {
      _inflight.remove(key);
      // Optional: notify if any UI cares about "in-flight" state.
      if (hasListeners) notifyListeners();
    });

    _inflight[key] = fut;
    return fut;
  }

  /// Optional: if you ever want to show "loading details" per row.
  bool isInflight({required int epoch, required int tier}) {
    return _inflight.containsKey(ResolvedGameKey(epoch, tier));
  }
}
