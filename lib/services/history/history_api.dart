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

    if (res.statusCode != 200) {
      throw Exception('winning-history failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      // { ok, count, lastEpoch, items }
      if (decoded.containsKey('ok') && decoded['ok'] != true) {
        throw Exception('winning-history returned ok=false');
      }
      return WinningHistoryResponse.fromApi(decoded);
    }

    // If you ever hit legacy array shape, we can support it, but it won’t have lastEpoch.
    throw Exception('Unexpected payload type (expected object with items/lastEpoch)');
  }
}
