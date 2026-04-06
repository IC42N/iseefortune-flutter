import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/models/game/game_db_model.dart';
import 'package:iseefortune_flutter/models/game_resolution/game_resolution_profile_result.dart';

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

  Future<List<ResolvedGameProfileResult>> getBatchByGameKeys(List<ResolvedGameLookupKey> keys) async {
    final deduped = <String, ResolvedGameLookupKey>{};
    for (final key in keys) {
      deduped[key.toApiKey()] = key;
    }

    final ordered = deduped.values.toList()
      ..sort((a, b) {
        final epochCmp = b.gameEpoch.compareTo(a.gameEpoch);
        if (epochCmp != 0) return epochCmp;
        return b.tier.compareTo(a.tier);
      });

    if (ordered.isEmpty) return const [];

    final joinedKeys = ordered.map((k) => k.toApiKey()).join(',');

    final uri = Uri.parse('$baseUrl/resolved-game?gameKeys=$joinedKeys');

    final res = await _client.get(uri, headers: {'accept': 'application/json'});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Resolved game batch API ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    Map<String, dynamic>? payload;

    // API Gateway proxy wrapper
    if (decoded is Map && decoded.containsKey('body')) {
      final body = decoded['body'];

      if (body is String && body.isNotEmpty) {
        final inner = jsonDecode(body);
        if (inner is Map) payload = Map<String, dynamic>.from(inner);
      } else if (body is Map) {
        payload = Map<String, dynamic>.from(body);
      }
    }
    // Direct payload
    else if (decoded is Map) {
      payload = Map<String, dynamic>.from(decoded);
    }

    if (payload == null) {
      throw Exception('Resolved game batch API returned empty payload');
    }

    if (payload['ok'] != true) {
      throw Exception('Resolved game batch API returned ok=false');
    }

    final items = payload['items'];
    if (items is! List) {
      throw Exception('Resolved game batch API missing items');
    }

    return items
        .whereType<Map>()
        .map((e) => ResolvedGameProfileResult.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
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

    if (payload['ok'] != true) return null;
    if (payload['core'] is! Map) return null;
    return ApiResolvedGameDto.fromJson(payload);
  }
}
