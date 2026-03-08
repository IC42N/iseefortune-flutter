import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/models/game/game_unified_model.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_repo.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

/// ResolvedGameProvider
/// ---------------------------------------------------------------------------
/// Owns the UI state for the "resolved game" panel.
///
/// Responsibilities:
/// - Fetch resolved-game data for a given (epoch, tier)
/// - Prefer API data, fallback to chain PDA (handled by repository)
/// - Expose loading/error/current model for the UI
/// - Protect against stale async results (runId token pattern)
///
/// Non-responsibilities:
/// - No networking / JSON parsing (services/repo)
/// - No PDA derivation/decoding (chain service)
/// - No long-term caching (repo handles per-key caching)
class ResolvedGamePanelProvider extends ChangeNotifier {
  ResolvedGamePanelProvider({required ResolvedGameRepository repo}) : _repo = repo;

  ResolvedGameRepository _repo;

  bool _loading = false;
  Object? _error;

  /// Currently displayed resolved game (for the panel).
  ResolvedGameHistoryModel? _current;

  /// Epoch corresponding to [_current].
  int? _currentEpoch;

  /// Selected tier (defaults to 1). History panel is tier-dependent.
  int _tier = 1;

  /// Cancellation / staleness token.
  ///
  /// This value increments when:
  /// - a new load starts
  /// - tier changes (invalidate in-flight)
  /// - repo changes (invalidate in-flight)
  ///
  /// Any async result that returns with an old token is ignored.
  int _runId = 0;

  // ---------------------------------------------------------------------------
  // Public getters (UI reads these via context.select)
  // ---------------------------------------------------------------------------

  bool get isLoading => _loading;
  Object? get lastError => _error;

  ResolvedGameHistoryModel? get current => _current;
  int? get currentEpoch => _currentEpoch;
  int get tier => _tier;

  // ---------------------------------------------------------------------------
  // Dependency wiring
  // ---------------------------------------------------------------------------

  /// Allows ProxyProvider to replace/inject the repository without recreating
  /// the provider instance.
  void attachRepo(ResolvedGameRepository repo) {
    if (identical(_repo, repo)) return;
    _repo = repo;

    // Treat repo swaps as "invalidate everything".
    _runId++;
    _current = null;
    _currentEpoch = null;
    _error = null;
    _loading = false;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Tier control
  // ---------------------------------------------------------------------------

  /// Update selected tier.
  ///
  /// IMPORTANT:
  /// - changing tier invalidates the resolved game panel
  /// - bumping _runId cancels in-flight requests
  void setTier(int tier) {
    final normalized = tier < 1 ? 1 : tier;
    if (_tier == normalized) return;

    _tier = normalized;

    // Cancel any in-flight request from the previous tier.
    _runId++;

    // Clear current view so UI doesn't show wrong-tier results.
    _current = null;
    _currentEpoch = null;
    _error = null;
    _loading = false;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Loading (public entrypoints)
  // ---------------------------------------------------------------------------

  /// Convenience: most of your app uses int epochs.
  Future<void> loadForEpochInt(int epoch) async {
    if (epoch < 0) return;

    // If switching epochs, clear immediately so the panel doesn't show stale data.
    // (This is a UX choice: "blank then load". If you prefer, keep old data
    // visible and show a small spinner instead.)
    if (_currentEpoch != epoch) {
      _current = null;
      _error = null;
      notifyListeners();
    }

    await _load(epoch: epoch, tier: _tier);
  }

  /// Load resolved game for a BigInt epoch (history uses BigInt).
  Future<void> loadForSelectedEpoch(BigInt epoch) async {
    if (epoch.isNegative) return;
    await loadForEpochInt(epoch.toInt());
  }

  // ---------------------------------------------------------------------------
  // Internal load
  // ---------------------------------------------------------------------------

  /// Internal load for (epoch,tier).
  ///
  /// Notes:
  /// - Uses _runId guard so quick taps or tier changes don't produce stale UI.
  /// - Sets loading BEFORE awaiting repo.
  Future<void> _load({required int epoch, required int tier}) async {
    final myRun = ++_runId;

    // If we’re already showing this exact data, skip.
    if (_currentEpoch == epoch && _tier == tier && _current != null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      icLogger.i('[ResolvedGameProvider] loading epoch=$epoch tier=$tier...');

      // Repository handles: try API first, then fallback to chain PDA.
      final model = await _repo.getByEpoch(epoch: epoch, tier: tier);

      // Ignore stale response if a newer run started (tap spam / tier changes / repo swap).
      if (myRun != _runId) return;

      // Extra safety: if tier changed while awaiting, do not commit.
      // (RunId usually covers this, but this makes it future-proof.)
      if (tier != _tier) return;
      _current = model;
      _currentEpoch = epoch;
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (myRun != _runId) return;

      icLogger.w('[ResolvedGameProvider] load failed epoch=$epoch tier=$tier: $e');
      _loading = false;
      _error = e;
      notifyListeners();
    }
  }
}
