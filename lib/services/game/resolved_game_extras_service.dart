import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/models/game/game_db_model.dart'; // ApiWinnerRow/ApiTicketRow (reuse)

class ResolvedGameExtrasApiService {
  ResolvedGameExtrasApiService({http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl = 'https://api.iseefortune.com';
  final http.Client _client;

  Future<ApiResolvedGameExtras?> getExtras({required int epoch, required int tier}) async {
    final uri = Uri.parse('$baseUrl/resolved-game/extras');

    final resp = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'epoch': epoch, 'tier': tier}),
    );

    if (resp.statusCode == 404) return null;
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Extras API ${resp.statusCode}: ${resp.body}');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    if (j['ok'] != true) return null;

    final winnersRaw = (j['winners'] as List?) ?? const [];
    final ticketsRaw = (j['tickets'] as List?) ?? const [];

    return ApiResolvedGameExtras(
      winners: winnersRaw
          .whereType<Map>()
          .map((m) => ApiWinnerRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      tickets: ticketsRaw
          .whereType<Map>()
          .map((m) => ApiTicketRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),
      keys: const {},
    );
  }
}
