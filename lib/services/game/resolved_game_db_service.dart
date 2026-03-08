import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/models/game/game_db_model.dart';

class ResolvedGameApiService {
  ResolvedGameApiService({http.Client? client, this.baseUrl = 'https://api.iseefortune.com'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<ApiResolvedGameDto?> getByEpoch({
    required int epoch,
    required int tier,
    bool includeExtras = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/resolved-game?epoch=$epoch&tier=$tier&includeExtras=${includeExtras ? 1 : 0}',
    );
    return _getResolvedDtoOrNull(uri);
  }

  Future<ApiResolvedGameDto?> _getResolvedDtoOrNull(Uri uri) async {
    final res = await _client.get(uri, headers: {'accept': 'application/json'});

    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    Map<String, dynamic>? payload;

    // API Gateway proxy wrapper: { statusCode, headers, body: "..." }
    if (decoded is Map && decoded.containsKey('body')) {
      final body = decoded['body'];

      if (body is String && body.isNotEmpty) {
        final inner = jsonDecode(body);
        if (inner is Map) payload = Map<String, dynamic>.from(inner);
      } else if (body is Map) {
        payload = Map<String, dynamic>.from(body);
      }
    }
    // Direct payload: { ok, gameEpoch, core, extras }
    else if (decoded is Map) {
      payload = Map<String, dynamic>.from(decoded);
    }

    if (payload == null) return null;

    // Your inner payload is: { ok:true, gameEpoch, tier, core:{...}, extras:{...} }
    if (payload['ok'] != true) return null;
    if (payload['core'] is! Map) return null;
    return ApiResolvedGameDto.fromJson(payload);
  }
}
