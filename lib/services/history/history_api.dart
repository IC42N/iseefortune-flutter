import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/models/winning_history_response.dart';

class WinningHistoryApi {
  WinningHistoryApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const int defaultLimit = 20;

  final Uri _baseUrl = Uri.parse('https://api.iseefortune.com/winning-history');

  Future<WinningHistoryResponse> fetchWinningHistory({int limit = defaultLimit}) async {
    final uri = _baseUrl.replace(queryParameters: {'limit': limit.toString()});

    final res = await _client.get(uri, headers: {'accept': 'application/json'});
    return _parseResponse(res, label: 'winning-history');
  }

  Future<WinningHistoryResponse> fetchWinningHistoryForEpochs(List<BigInt> epochs) async {
    final uniqueSorted = epochs.toSet().toList()..sort((a, b) => b.compareTo(a));

    if (uniqueSorted.isEmpty) {
      return WinningHistoryResponse.fromApi({'ok': true, 'count': 0, 'lastEpoch': null, 'items': []});
    }

    final uri = _baseUrl.replace(
      queryParameters: {'epochs': uniqueSorted.map((e) => e.toString()).join(',')},
    );

    final res = await _client.get(uri, headers: {'accept': 'application/json'});
    return _parseResponse(res, label: 'winning-history by epochs');
  }

  WinningHistoryResponse _parseResponse(http.Response res, {required String label}) {
    if (res.statusCode != 200) {
      throw Exception('$label failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('ok') && decoded['ok'] != true) {
        throw Exception('$label returned ok=false');
      }
      return WinningHistoryResponse.fromApi(decoded);
    }

    throw Exception('Unexpected payload type (expected object with items/lastEpoch)');
  }
}
