import 'winning_history_row.dart';

class WinningHistoryResponse {
  WinningHistoryResponse({required this.items, required this.lastEpoch, required this.count});

  final List<WinningHistoryRow> items;
  final BigInt? lastEpoch;
  final int? count;

  static BigInt? _bi(dynamic v) {
    if (v == null) return null;
    if (v is int) return BigInt.from(v);
    if (v is num) return BigInt.from(v.toInt());
    if (v is String) return BigInt.parse(v);
    return null;
  }

  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory WinningHistoryResponse.fromApi(Map<String, dynamic> decoded) {
    final maybe = decoded['items'];
    if (maybe is! List) {
      throw Exception('Unexpected payload shape (items missing or not a list)');
    }

    final rows = maybe.whereType<Map<String, dynamic>>().map(WinningHistoryRow.fromJson).toList();

    // newest first
    rows.sort((a, b) => b.epoch.compareTo(a.epoch));

    return WinningHistoryResponse(
      items: rows,
      lastEpoch: _bi(decoded['lastEpoch']),
      count: _i(decoded['count']),
    );
  }
}
