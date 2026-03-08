class WinningHistoryRow {
  WinningHistoryRow({
    required this.pk,
    required this.epoch,
    required this.endSlot,
    required this.rngBlockhashBase58,
    required this.slotUsed,
    required this.winningNumber,
  });

  final String pk;
  final BigInt epoch;
  final BigInt? endSlot;
  final String? rngBlockhashBase58;
  final BigInt? slotUsed;
  final int winningNumber;

  factory WinningHistoryRow.fromJson(Map<String, dynamic> j) {
    BigInt? bi(dynamic v, String label, {bool required = false}) {
      if (v == null) {
        if (required) throw StateError('$label missing');
        return null;
      }
      if (v is int) return BigInt.from(v);
      if (v is num) return BigInt.from(v.toInt());
      if (v is String) return BigInt.parse(v);
      throw StateError('$label expected number/string. got=${v.runtimeType}');
    }

    int mustInt(dynamic v, String label) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.parse(v);
      throw StateError('$label expected int. got=${v.runtimeType}');
    }

    final pk = j['pk'];
    if (pk is! String || pk.isEmpty) throw StateError('pk missing/invalid');

    return WinningHistoryRow(
      pk: pk,
      epoch: bi(j['epoch'], 'epoch', required: true)!,
      endSlot: bi(j['endSlot'], 'endSlot'),
      rngBlockhashBase58: j['rngBlockhashBase58'] as String?,
      slotUsed: bi(j['slotUsed'], 'slotUsed'),
      winningNumber: mustInt(j['winningNumber'], 'winningNumber'),
    );
  }
}
