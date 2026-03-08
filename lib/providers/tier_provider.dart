import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TierProvider
/// ---------------------------------------------------------------------------
/// Owns the user's *selected tier* for the game.
///
/// Responsibilities:
/// - Persist the selected tier across app restarts
/// - Provide a default tier (1) when nothing is stored
/// - Expose a `isReady` flag so the UI knows when it is safe to render
///
/// IMPORTANT:
/// - No tier-dependent game UI should render until `isReady == true`
/// - This prevents flashing tier=1 before the persisted tier is loaded
class TierProvider extends ChangeNotifier {
  /// SharedPreferences key
  static const _prefsKey = 'selected_tier';

  /// Current selected tier (defaults to 1 until loaded)
  int _tier = 1;
  int get tier => _tier;

  /// Indicates whether the tier has been loaded from persistence
  /// UI should wait for this before rendering tier-dependent data
  bool _ready = false;
  bool get isReady => _ready;

  /// Load the persisted tier from SharedPreferences.
  ///
  /// This MUST be called during app bootstrap before:
  /// - fetching tier-dependent PDAs
  /// - hydrating cached LiveFeed data
  /// - starting tier-specific subscriptions
  ///
  /// Once complete, `isReady` becomes true and listeners are notified.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getInt(_prefsKey);

    // Normalize: tier must always be >= 1
    _tier = (saved == null || saved < 1) ? 1 : saved;

    _ready = true;
    notifyListeners();
  }

  /// Update the selected tier.
  ///
  /// Intended to be called when the user switches tiers
  /// (e.g. via a UI selector in a future version).
  ///
  /// This:
  /// - Updates in-memory state
  /// - Persists the tier
  /// - Notifies listeners so tier-dependent providers can react
  Future<void> setTier(int nextTier) async {
    final normalized = nextTier < 1 ? 1 : nextTier;

    if (normalized == _tier) return;

    _tier = normalized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _tier);
  }
}
