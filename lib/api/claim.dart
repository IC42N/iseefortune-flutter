// lib/services/claim/build_claim_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/constants/app.dart';

class BuildClaimResponse {
  final bool ok;
  final int v;
  final String action;

  // helpful metadata (new)
  final int firstEpochInChain;
  final int tier;
  final int claimIndex;
  final int payoutLamports;

  final String messageB64;
  final String transactionB64;
  final String recentBlockhash;
  final Map<String, dynamic> accounts;

  BuildClaimResponse({
    required this.ok,
    required this.v,
    required this.action,
    required this.firstEpochInChain,
    required this.tier,
    required this.claimIndex,
    required this.payoutLamports,
    required this.messageB64,
    required this.transactionB64,
    required this.recentBlockhash,
    required this.accounts,
  });

  factory BuildClaimResponse.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return BuildClaimResponse(
      ok: json['ok'] == true,
      v: asInt(json['v'], fallback: 0),
      action: (json['action'] as String?) ?? '',

      firstEpochInChain: asInt(json['first_epoch_in_chain']),
      tier: asInt(json['tier']),
      claimIndex: asInt(json['claim_index']),
      payoutLamports: asInt(json['payout_lamports']),

      messageB64: (json['message_b64'] as String?) ?? '',
      transactionB64: (json['message_b64'] as String?) ?? '',
      recentBlockhash: (json['recent_blockhash'] as String?) ?? '',
      accounts: (json['accounts'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class BuildClaimApiException implements Exception {
  BuildClaimApiException(this.statusCode, this.body, this.payload, this.apiUrl);

  final int statusCode;
  final String body;
  final Map<String, dynamic> payload;
  final String apiUrl;

  @override
  String toString() =>
      'Build claim failed: $statusCode\n$body\nPayload: ${jsonEncode(payload)}\nAPI URL: $apiUrl';
}

Future<BuildClaimResponse> buildUnsignedClaimMessage(Map<String, dynamic> payload) async {
  const apiUrl = 'https://api.iseefortune.com/claim/tx/build';

  final res = await http.post(
    Uri.parse(apiUrl),
    headers: {'content-type': 'application/json', 'x-api-key': AppConstants.apiKey},
    body: jsonEncode(payload),
  );

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final decoded = jsonDecode(res.body);

    // Case A: direct lambda proxy (already the inner object)
    if (decoded is Map<String, dynamic> && decoded.containsKey('ok')) {
      return BuildClaimResponse.fromJson(decoded);
    }

    // Case B: API Gateway wrapper: { statusCode, headers, body: "..." }
    if (decoded is Map<String, dynamic> && decoded['body'] is String) {
      final inner = jsonDecode(decoded['body'] as String);
      if (inner is Map<String, dynamic>) {
        return BuildClaimResponse.fromJson(inner);
      }
    }

    // Unknown shape
    throw BuildClaimApiException(res.statusCode, res.body, payload, apiUrl);
  }

  throw BuildClaimApiException(res.statusCode, res.body, payload, apiUrl);
}

/// Convenience wrapper for the new Claim Tx Builder (prediction PDA + claimer)
Future<BuildClaimResponse> buildClaimTx({required String claimer, required String predictionPda}) {
  return buildUnsignedClaimMessage({
    'v': 2,
    'action': 'claim',
    'claimer': claimer,
    'prediction_pda': predictionPda,
  });
}
