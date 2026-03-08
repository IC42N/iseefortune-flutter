import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/utils/choice_encoding.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/numbers/selections.dart';

/// How the modal was opened:
/// - create: user is placing a new prediction
/// - manage: user already has a prediction and is managing it
enum SubmitModalEntry { create, manage }

/// Optional internal intent flag for the manage menu (not required yet)
enum ManageIntent { none, increase, change }

enum PredictionTypeUi { single, split, highLow, evenOdd }

enum HighLowChoice { low, high }

enum EvenOddChoice { even, odd }

/// Wire-level action that determines which backend path we hit.
enum PredictionAction { place, changeNumber, increase }

extension PredictionActionWire on PredictionAction {
  String get wire => switch (this) {
    PredictionAction.place => 'place',
    PredictionAction.changeNumber => 'change_number',
    PredictionAction.increase => 'increase',
  };
}

class SubmitPredictionState extends ChangeNotifier {
  /// Current action for this modal session.
  /// NOTE: In manage-entry, user may start on the manage menu with a placeholder action
  /// and then choose increase/change which updates this.
  PredictionAction action = PredictionAction.place;

  /// The selectable digit domain for this epoch/tier (usually excludes rollover digit).
  /// IMPORTANT: This is set by the modal opener (from LiveFeedVM).
  List<int> selectableNumbers = const [];

  /// Current selection set used by the UI.
  /// In create flow: must be subset of selectableNumbers.
  /// In manage flow: may include a locked digit (rollover), so we preserve baseNumbers.
  final Set<int> numbers = <int>{};

  /// Step index within modal:
  /// - step 0: selection screen OR manage menu (depends on isManageEntry)
  /// - step 1: wager/review screen
  int step = 0;

  /// Per-number amount:
  /// - place flow: this is the full wager per number
  /// - increase flow: this is the *additional* wager per number
  double amountSol = 0.05;

  /// Lock UI while submitting.
  bool isSubmitting = false;

  /// Where the modal was opened from (create vs manage).
  SubmitModalEntry entry = SubmitModalEntry.create;

  // ---------------------------------------------------------------------------
  // Manage flow flags
  // ---------------------------------------------------------------------------

  /// When true, step 0 shows "Manage your prediction" menu instead of selection UI.
  bool isManageEntry = false;

  /// True only when user entered selection UI from manage menu (change-number path),
  /// used for showing a back arrow on step 0.
  bool fromManageToChange = false;

  // ---------------------------------------------------------------------------
  // Baselines (manage entry only)
  // ---------------------------------------------------------------------------

  /// Original selection from the existing on-chain prediction.
  /// Used to prevent changing the selection during increase
  /// and to allow preserving rollover/locked digits.
  Set<int> baseNumbers = <int>{};

  /// Original selection count, used for change-number restriction:
  /// user must pick exactly this many.
  int baseSelectionCount = 0;

  /// Original wager (per number) from the existing prediction.
  /// Used for increase UI (“was + add = new”) and for change-number review
  /// (change does NOT modify amount).
  double baseAmountSol = 0.0;

  /// Helpers to make the UI read cleaner
  bool get isIncreaseFlow => action == PredictionAction.increase;
  bool get isChangeFlow => action == PredictionAction.changeNumber;

  // ---------------------------------------------------------------------------
  // Open / initialize modal state
  // ---------------------------------------------------------------------------

  void open({
    required SubmitModalEntry entry,
    required PredictionAction action,
    Uint8List? initialNumbers,
    BigInt? initialLamportsPerNumber,
  }) {
    this.entry = entry;

    // isManageEntry drives what step 0 renders (manage menu vs selection UI)
    isManageEntry = (entry == SubmitModalEntry.manage);
    fromManageToChange = false;

    this.action = action;
    step = 0;
    isSubmitting = false;

    icLogger.i(
      "SubmitPredictionState opened with entry=$entry, action=$action, "
      "initialNumbers=${initialNumbers != null ? selectionsU8x8ToSet(initialNumbers) : 'null'}, "
      "initialLamportsPerNumber=${initialLamportsPerNumber != null ? initialLamportsPerNumber.toString() : 'null'}",
    );

    // -------------------------
    // Preload numbers
    // -------------------------
    numbers.clear();

    if (initialNumbers != null) {
      final raw = selectionsU8x8ToSet(initialNumbers); // {1..9} from the on-chain u8x8 array

      if (entry == SubmitModalEntry.manage) {
        // Manage entry: preserve EXACT selection, including locked/rollover numbers
        numbers.addAll(raw);

        // Save baselines for manage flows
        baseNumbers = {...raw};
        baseSelectionCount = raw.length;
      } else {
        // Create entry: enforce selectable domain (rollover digit should be filtered out)
        final filtered = raw.where(_selectableSet.contains).toSet();
        numbers.addAll(filtered);
      }
    } else {
      baseNumbers = <int>{};
      baseSelectionCount = 0;
    }

    // -------------------------
    // Baseline wager per number (manage entry)
    // -------------------------
    if (initialLamportsPerNumber != null) {
      baseAmountSol = initialLamportsPerNumber.toDouble() / 1e9;
    } else {
      baseAmountSol = 0.0;
    }

    // Default amount:
    // - place: start at min
    // - increase: start at min additional (still 0.01)
    amountSol = 0.01;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Manage menu actions
  // ---------------------------------------------------------------------------

  void chooseIncrease() {
    // Enter increase route: selection is locked to baseNumbers
    action = PredictionAction.increase;
    step = 1;

    // HARD LOCK: ensure selections exist on wager screen
    numbers
      ..clear()
      ..addAll(baseNumbers);

    icLogger.i("chooseIncrease numbers=${numbers.toString()} baseNumbers=$baseNumbers");
    notifyListeners();
  }

  void chooseChange() {
    // Enter change-number route:
    // step 0 becomes selection UI (not the manage menu)
    action = PredictionAction.changeNumber;
    isManageEntry = false;
    fromManageToChange = true;
    step = 0;

    // Start selection at baseline selection (same count must be maintained)
    numbers
      ..clear()
      ..addAll(baseNumbers);

    notifyListeners();
  }

  void backToManage() {
    // Return to manage menu screen
    isManageEntry = true;
    fromManageToChange = false;
    step = 0;

    // Restore original numbers and reset additional amount
    numbers
      ..clear()
      ..addAll(baseNumbers);

    amountSol = 0.01;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Optional legacy setter (careful: this clears numbers)
  // ---------------------------------------------------------------------------

  /// Sets the selectable domain for this epoch/tier.
  /// In manage entry, we preserve baseNumbers even if they aren’t selectable now.
  void setSelectableNumbers(List<int> ns) {
    final cleaned = ns.where((n) => n >= 1 && n <= 9).toList()..sort();

    bool shouldKeep(int n) {
      // Manage entry: keep original locked-in selections
      if (entry == SubmitModalEntry.manage) return baseNumbers.contains(n) || cleaned.contains(n);
      return cleaned.contains(n);
    }

    // Same domain: still sanitize selections
    if (listEquals(selectableNumbers, cleaned)) {
      final before = numbers.length;
      numbers.removeWhere((n) => !shouldKeep(n));
      if (numbers.length != before) notifyListeners();
      return;
    }

    selectableNumbers = cleaned;

    // Domain changed: sanitize selections
    final before = numbers.length;
    numbers.removeWhere((n) => !shouldKeep(n));
    if (numbers.length != before) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Derived inference (type = single/split/highlow/evenodd)
  // ---------------------------------------------------------------------------

  PredictionTypeUi get type {
    if (numbers.isEmpty) return PredictionTypeUi.single;

    // Full-set patterns override split/single
    if (inferredEvenOdd != null) return PredictionTypeUi.evenOdd;
    if (inferredHighLow != null) return PredictionTypeUi.highLow;

    if (numbers.length == 1) return PredictionTypeUi.single;
    return PredictionTypeUi.split;
  }

  EvenOddChoice? get inferredEvenOdd {
    if (numbers.isEmpty) return null;
    final domain = _selectableSet;
    if (domain.isEmpty) return null;

    final evens = domain.where((n) => n.isEven).toSet();
    final odds = domain.where((n) => n.isOdd).toSet();

    if (evens.isNotEmpty && _setEquals(numbers, evens)) return EvenOddChoice.even;
    if (odds.isNotEmpty && _setEquals(numbers, odds)) return EvenOddChoice.odd;
    return null;
  }

  HighLowChoice? get inferredHighLow {
    if (numbers.isEmpty) return null;
    final (low, high) = _halves();
    if (low.isNotEmpty && _setEquals(numbers, low)) return HighLowChoice.low;
    if (high.isNotEmpty && _setEquals(numbers, high)) return HighLowChoice.high;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Mutations for selection UI
  // ---------------------------------------------------------------------------

  void toggleNumber(int n) {
    // Enforce domain (locked numbers cannot be added if not selectable)
    if (!_selectableSet.contains(n)) return;

    if (numbers.contains(n)) {
      numbers.remove(n);
    } else {
      numbers.add(n);
    }
    notifyListeners();
  }

  void setNumbers(Iterable<int> ns) {
    final domain = _selectableSet;
    numbers
      ..clear()
      ..addAll(ns.where(domain.contains));
    notifyListeners();
  }

  void clearNumbers() {
    if (numbers.isEmpty) return;
    numbers.clear();
    notifyListeners();
  }

  // Quick actions

  void selectEven() => setNumbers(selectableNumbers.where((n) => n.isEven));
  void selectOdd() => setNumbers(selectableNumbers.where((n) => n.isOdd));

  void selectHigh() {
    final (_, high) = _halves();
    setNumbers(high);
  }

  void selectLow() {
    final (low, _) = _halves();
    setNumbers(low);
  }

  /// UX helper: tap selects single number (toggles off if already selected).
  void selectSingleNumber(int n) {
    if (!_selectableSet.contains(n)) return;

    if (numbers.length == 1 && numbers.contains(n)) {
      numbers.clear();
      notifyListeners();
      return;
    }

    numbers
      ..clear()
      ..add(n);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Step + submit flags
  // ---------------------------------------------------------------------------

  void setAmountSol(double v) {
    amountSol = v;
    notifyListeners();
  }

  void nextStep() {
    step += 1;
    notifyListeners();
  }

  void prevStep() {
    if (step == 0) return;
    step -= 1;
    notifyListeners();
  }

  void setSubmitting(bool v) {
    if (isSubmitting == v) return;
    isSubmitting = v;
    notifyListeners();
  }

  Future<T> runSubmitting<T>(Future<T> Function() fn) async {
    setSubmitting(true);
    try {
      return await fn();
    } finally {
      setSubmitting(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Validation / derived helpers
  // ---------------------------------------------------------------------------

  List<int> get sortedNums => (numbers.toList()..sort());

  int get predictionTypeCode => switch (type) {
    PredictionTypeUi.single => 0,
    PredictionTypeUi.split => 1,
    PredictionTypeUi.highLow => 2,
    PredictionTypeUi.evenOdd => 3,
  };

  bool get hasValidSelection {
    switch (type) {
      case PredictionTypeUi.single:
        return numbers.length == 1;
      case PredictionTypeUi.split:
        return numbers.isNotEmpty && numbers.length <= 8;
      case PredictionTypeUi.highLow:
        return inferredHighLow != null;
      case PredictionTypeUi.evenOdd:
        return inferredEvenOdd != null;
    }
  }

  String? get selectionError {
    if (numbers.isEmpty) return 'Pick at least 1 number.';

    // Change-number restriction: must keep same count
    if (action == PredictionAction.changeNumber) {
      if (baseSelectionCount > 0 && numbers.length != baseSelectionCount) {
        return 'Must select exactly $baseSelectionCount numbers.';
      }
    }

    switch (type) {
      case PredictionTypeUi.single:
        if (numbers.length != 1) return 'Pick exactly 1 number.';
        return null;

      case PredictionTypeUi.split:
        if (numbers.length > 8) return 'Pick up to 8 numbers.';
        return null;

      case PredictionTypeUi.highLow:
        if (inferredHighLow == null) return 'Pick a full LOW or HIGH set.';
        return null;

      case PredictionTypeUi.evenOdd:
        if (inferredEvenOdd == null) return 'Pick a full EVEN or ODD set.';
        return null;
    }
  }

  bool get needsSelection => action != PredictionAction.increase;
  bool get canContinue => (!needsSelection || hasValidSelection) && !isSubmitting;

  // ---------------------------------------------------------------------------
  // Anchor choice encoding + payload
  // ---------------------------------------------------------------------------

  int _buildChoiceU32() {
    final nums = sortedNums;

    switch (type) {
      case PredictionTypeUi.single:
        return nums.first;

      case PredictionTypeUi.split:
        if (nums.any((n) => n < 1 || n > 9)) {
          throw StateError('Invalid split digits');
        }
        return encodeChoiceDigits(nums);

      case PredictionTypeUi.highLow:
        final hl = inferredHighLow;
        if (hl == null) throw StateError('Invalid high/low selection');
        return (hl == HighLowChoice.high) ? 1 : 0;

      case PredictionTypeUi.evenOdd:
        final eo = inferredEvenOdd;
        if (eo == null) throw StateError('Invalid even/odd selection');
        return (eo == EvenOddChoice.odd) ? 1 : 0;
    }
  }

  int _lamportsU64Rounded() => (amountSol * 1e9).round();

  Map<String, dynamic> toPayload({
    required String playerWalletPubkey,
    required int tier,
    required String gameEpoch,
  }) {
    if (!hasValidSelection) {
      throw StateError(selectionError ?? 'Invalid selection');
    }

    final choiceU32 = _buildChoiceU32();

    switch (action) {
      case PredictionAction.place:
        return {
          'action': action.wire,
          'v': 1,
          'player': playerWalletPubkey,
          'tier': tier,
          'game_epoch': gameEpoch,
          'prediction_type': predictionTypeCode,
          'choice': choiceU32,
          'lamports_per_number': _lamportsU64Rounded().toString(),
        };

      case PredictionAction.changeNumber:
        return {
          'action': action.wire,
          'v': 1,
          'player': playerWalletPubkey,
          'tier': tier,
          'game_epoch': gameEpoch,
          'new_prediction_type': predictionTypeCode,
          'new_choice': choiceU32,
        };

      case PredictionAction.increase:
        return {
          'action': action.wire,
          'v': 1,
          'player': playerWalletPubkey,
          'tier': tier,
          'game_epoch': gameEpoch,
          'additional_lamports_per_number': _lamportsU64Rounded().toString(),
          'choice': choiceU32,
        };
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Set<int> get _selectableSet => selectableNumbers.toSet();

  (Set<int>, Set<int>) _halves() {
    final list = [...selectableNumbers]..sort();
    if (list.isEmpty) return (<int>{}, <int>{});

    final mid = (list.length / 2).floor();
    final low = list.take(mid).toSet();
    final high = list.skip(mid).toSet();
    return (low, high);
  }

  bool _setEquals(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b) && b.containsAll(a);
}

bool changedSelection(SubmitPredictionState s) {
  // "Changed" means not exactly equal to the original base selection set.
  return !(s.numbers.length == s.baseNumbers.length && s.numbers.containsAll(s.baseNumbers));
}
