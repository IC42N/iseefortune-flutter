// lib/utils/number_stats/selectable_numbers.dart

/// Returns the list of selectable digits (0–9),
/// excluding the primary and secondary rollover numbers if they are valid.
///
/// Domain rules:
/// - Valid rollover numbers are integers in the range 0..9 (inclusive)
/// - Invalid values are ignored
/// - Output is sorted ascending and non-growable
List<int> selectableNumbersFromRollover({
  required int primaryRollOverNumber,
  required int secondaryRollOverNumber,
}) {
  // Build a set of excluded numbers.
  // Using a Set guarantees uniqueness even if both rollovers are the same.
  final excluded = <int>{
    if (primaryRollOverNumber >= 0 && primaryRollOverNumber <= 9) primaryRollOverNumber,
    if (secondaryRollOverNumber >= 0 && secondaryRollOverNumber <= 9) secondaryRollOverNumber,
  };

  // Generate the full domain [0..9] and remove excluded values.
  return List<int>.generate(10, (i) => i).where((n) => !excluded.contains(n)).toList(growable: false);
}
