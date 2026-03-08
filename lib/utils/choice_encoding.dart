int encodeChoiceDigits(List<int> numbers) {
  // Remove zeros and invalid digits, then de-dupe + sort for determinism
  final set = <int>{};
  for (final n in numbers) {
    if (n >= 1 && n <= 9) set.add(n);
  }

  final sorted = set.toList()..sort(); // canonical order
  if (sorted.isEmpty) return 0; // caller should prevent this

  // Pack digits into a u32: e.g., [3,4,5] -> 345
  var choice = 0;
  for (final n in sorted) {
    choice = (choice * 10) + n;
  }

  // This is always safe for up to 8 digits (max 98765432) < 2^32
  return choice;
}

/// Debug / sanity: decode u32 like 8746 -> [8,7,4,6]
List<int> decodeChoiceDigits(int choice) {
  if (choice <= 0) return const [];
  final out = <int>[];
  var x = choice;
  while (x > 0) {
    out.add(x % 10);
    x ~/= 10;
  }
  return out; // order is “right to left”
}
