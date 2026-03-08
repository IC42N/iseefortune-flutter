import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/constants/app.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

class JsonRpcRaw {
  static int _id = 1;

  static Future<dynamic> call(
    String method, {
    List<dynamic> params = const [],
    String? url,
    String? tag, // optional caller tag for log filtering
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final headers = const {'content-type': 'application/json'};
    final endpoint = url ?? AppConstants.rawAPIURL;

    final payload = {'jsonrpc': '2.0', 'id': _id++, 'method': method, 'params': params};

    final label = tag == null ? '' : '[$tag] ';
    final sw = Stopwatch()..start();

    try {
      icLogger.d('$label [RPC] -> $method ($endpoint)');

      final res = await http
          .post(Uri.parse(endpoint), headers: headers, body: jsonEncode(payload))
          .timeout(timeout);

      sw.stop();

      if (res.statusCode != 200) {
        icLogger.w('$label [RPC] <- $method ${res.statusCode} (${sw.elapsedMilliseconds}ms)');
        throw Exception('RPC ${res.statusCode}: ${res.body}');
      }

      final body = jsonDecode(res.body);

      final err = body['error'];
      if (err != null) {
        final msg = (err is Map && err['message'] != null) ? err['message'] : err.toString();
        icLogger.w('$label [RPC] <- $method error (${sw.elapsedMilliseconds}ms) $msg');
        throw Exception('RPC error: $err');
      }

      icLogger.d('$label [RPC] <- $method ok (${sw.elapsedMilliseconds}ms)');
      return body['result'];
    } catch (e) {
      if (sw.isRunning) sw.stop();
      icLogger.e('$label [RPC] !! $method failed (${sw.elapsedMilliseconds}ms): $e');
      rethrow;
    }
  }
}
