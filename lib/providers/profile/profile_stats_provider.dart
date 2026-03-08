import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/models/profile/profile_stats_model.dart';
import 'package:iseefortune_flutter/services/profile/profile_stats_service.dart';

/// Internal wrapper that stores:
/// - The actual stats
/// - When they were fetched (used for TTL caching)
class _CacheEntry {
  _CacheEntry({required this.stats, required this.fetchedAt});

  ProfileStatsModel stats;
  DateTime fetchedAt;
}

/// ProfileStatsProvider
///
/// Responsibilities:
/// - Fetch profile stats from API
/// - Cache results per handle
/// - Prevent duplicate concurrent requests
/// - Respect TTL (time-to-live) for caching
/// - Notify listeners only when it matters (changed data, first-load loading, errors)
class ProfileStatsProvider extends ChangeNotifier {
  ProfileStatsProvider({ProfileStatsService? service, Duration ttl = const Duration(seconds: 10)})
    : _service = service ?? ProfileStatsService(),
      _ttl = ttl;

  final ProfileStatsService _service;

  /// How long cached stats are considered fresh.
  final Duration _ttl;

  /// key = HANDLE (uppercased)
  final Map<String, _CacheEntry> _cache = {};

  /// Tracks in-flight requests per handle
  final Map<String, Future<void>> _inflight = {};

  /// Last error per handle (optional UI usage)
  final Map<String, Object?> _errors = {};

  // ============================================================
  // Helpers
  // ============================================================

  String _key(String handle) => handle.trim().toUpperCase();

  bool _isStale(String k) {
    final e = _cache[k];
    if (e == null) return true;
    return DateTime.now().difference(e.fetchedAt) > _ttl;
  }

  // ============================================================
  // Public API (Used by UI)
  // ============================================================

  ProfileStatsModel? getCached(String handle) => _cache[_key(handle)]?.stats;

  bool isLoading(String handle) => _inflight.containsKey(_key(handle));

  Object? lastError(String handle) => _errors[_key(handle)];

  void clear(String handle) {
    final k = _key(handle);
    final removedCache = _cache.remove(k) != null;
    final removedError = _errors.remove(k) != null;
    if (removedCache || removedError) notifyListeners();
  }

  /// Call this when profile opens.
  ///
  /// Behavior:
  /// - If cache is fresh and force=false -> do nothing (no loading flash)
  /// - If already fetching -> reuse inflight future
  /// - If stale/missing -> fetch
  ///
  /// UI behavior:
  /// - If there is NO cached stats yet, we notify when loading starts so UI can show "Updating…"
  /// - If cached stats exist, we do NOT notify at loading start (prevents "Updating…" flash)
  Future<void> refresh(String handle, {bool force = false}) {
    final k = _key(handle);
    if (k.isEmpty) return Future.value();

    final stale = _isStale(k);
    if (!force && !stale) return Future.value();

    final existing = _inflight[k];
    if (existing != null) return existing;

    final hadCache = _cache.containsKey(k);

    // Optional: clear previous error as soon as we attempt again
    if (_errors[k] != null) {
      _errors[k] = null;
      // Only worth notifying if UI might be showing an error state
      if (!hadCache) notifyListeners();
    }

    Future<void> fut = _doFetch(k);

    // Put into inflight BEFORE notifying so isLoading(handle) is true during rebuilds.
    _inflight[k] = fut;

    // Only show "Updating..." (loading state) when there is no cached data yet.
    if (!hadCache) {
      notifyListeners();
    }

    fut = fut.whenComplete(() {
      _inflight.remove(k);

      // If we showed loading on first-load, notify again so UI can remove "Updating..."
      if (!hadCache) {
        notifyListeners();
      }
    });

    // Keep the wrapped future stored (so callers get the same completion semantics)
    _inflight[k] = fut;

    return fut;
  }

  // ============================================================
  // Internal Fetch
  // ============================================================

  Future<void> _doFetch(String k) async {
    try {
      final next = await _service.fetchProfileStats(handle: k);

      final prev = _cache[k]?.stats;
      final changed = prev == null ? true : !prev.sameAs(next);

      _cache[k] = _CacheEntry(stats: next, fetchedAt: DateTime.now());
      _errors[k] = null;

      // Notify only if data actually changed.
      if (changed) notifyListeners();
    } catch (e) {
      _errors[k] = e;
      notifyListeners();
    }
  }
}
