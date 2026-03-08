// lib/api/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri _u(String path, [Map<String, String>? qs]) =>
      Uri.parse(baseUrl).replace(path: path, queryParameters: qs);

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    required T Function(dynamic json) parser,
  }) async {
    final res = await _http.get(_u(path, query), headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('HTTP ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    return parser(decoded);
  }

  Future<T> postJson<T>(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    required Object body,
    required T Function(dynamic json) parser,
  }) async {
    final h = <String, String>{'content-type': 'application/json', ...?headers};

    final res = await _http.post(_u(path, query), headers: h, body: jsonEncode(body));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return parser(decoded);
  }
}
