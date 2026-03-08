import 'dart:typed_data';

Set<int> selectionsToSet(Uint8List selections) {
  final out = <int>{};
  final n = selections.length < 8 ? selections.length : 8;

  for (var i = 0; i < n; i++) {
    final v = selections[i];
    if (v >= 1 && v <= 9) out.add(v);
  }

  return out;
}

List<int> selectionsToSortedList(Uint8List selections) {
  final list = selectionsToSet(selections).toList()..sort();
  return list;
}

Set<int> selectionsU8x8ToSet(Uint8List selections) {
  final out = <int>{};
  final n = selections.length < 8 ? selections.length : 8;

  for (var i = 0; i < n; i++) {
    final v = selections[i];
    if (v >= 1 && v <= 9) out.add(v);
  }

  return out;
}
