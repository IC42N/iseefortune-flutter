import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/constants/app.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

Future<int> fetchLamports(String pubkey, {String? url}) async {
  final rpcUrl = url ?? AppConstants.rawAPIURL;

  try {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "getBalance",
        "params": [pubkey],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('RPC ${response.statusCode}: ${response.body}');
    }

    if (response.body.isEmpty) {
      throw Exception('Empty response from RPC');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final lamports = (json['result']?['value'] as int?) ?? 0;

    icLogger.i('[RPC] Balance for $pubkey: $lamports lamports');
    return lamports;
  } catch (e, st) {
    icLogger.e('[RPC] Failed to fetch balance: $e\n$st');
    rethrow; // ⬅️ important
  }
}
