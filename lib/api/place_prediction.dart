import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iseefortune_flutter/constants/app.dart';

/// Matches your Lambda BuildOk response.
class BuildPredictionResponse {
  final bool ok;
  final int v;
  final String action;
  final String messageB64;
  final String transactionB64;
  final String recentBlockhash;
  final Map<String, dynamic> accounts;

  BuildPredictionResponse({
    required this.ok,
    required this.v,
    required this.action,
    required this.messageB64,
    required this.transactionB64,
    required this.recentBlockhash,
    required this.accounts,
  });

  factory BuildPredictionResponse.fromJson(Map<String, dynamic> json) {
    return BuildPredictionResponse(
      ok: json['ok'] == true,
      v: (json['v'] as num).toInt(),
      action: (json['action'] as String?) ?? '',
      messageB64: (json['message_b64'] as String?) ?? '',
      transactionB64: (json['transaction_b64'] as String?) ?? '',
      recentBlockhash: (json['recent_blockhash'] as String?) ?? '',
      accounts: (json['accounts'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// If you want to keep your existing PlacePredictionRequest model, that's fine.
/// The only requirement is payload.toJson() must include:
///  - action: "place" | "change_number" | "increase"
///  - v: 1
///  - player, tier, game_epoch
///  - plus the action-specific fields
Future<BuildPredictionResponse> buildUnsignedPredictionMessage(Map<String, dynamic> payload) async {
  const apiUrl = 'https://api.iseefortune.com/prediction/tx/build';

  // If you still require x-api-key:
  // - best practice: don't hardcode in git
  // - but if you insist, keep it. (I recommend moving it to --dart-define.)

  final res = await http.post(
    Uri.parse(apiUrl),
    headers: {'content-type': 'application/json', 'x-api-key': AppConstants.apiKey},
    body: jsonEncode(payload),
  );

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return BuildPredictionResponse.fromJson(json);
  }

  throw Exception(
    'Build prediction message failed: ${res.statusCode}\n${res.body} \nPayload: ${jsonEncode(payload)} \nAPI URL: $apiUrl',
  );
}

/// Convenience wrappers (optional)
Future<BuildPredictionResponse> buildPlacePrediction({
  required int tier,
  required String player,
  required String gameEpoch, // u64 string
  required int predictionType,
  required int choice,
  required String lamportsPerNumber, // u64 string
}) {
  return buildUnsignedPredictionMessage({
    'action': 'place',
    'v': 1,
    'player': player,
    'tier': tier,
    'game_epoch': gameEpoch,
    'prediction_type': predictionType,
    'choice': choice,
    'lamports_per_number': lamportsPerNumber,
  });
}

Future<BuildPredictionResponse> buildChangeNumber({
  required int tier,
  required String player,
  required String gameEpoch,
  required int newPredictionType,
  required int newChoice,
}) {
  return buildUnsignedPredictionMessage({
    'action': 'change_number',
    'v': 1,
    'player': player,
    'tier': tier,
    'game_epoch': gameEpoch,
    'new_prediction_type': newPredictionType,
    'new_choice': newChoice,
  });
}

Future<BuildPredictionResponse> buildIncreasePrediction({
  required int tier,
  required String player,
  required String gameEpoch,
  required String additionalLamportsPerNumber, // u64 string
  required int choice,
}) {
  return buildUnsignedPredictionMessage({
    'action': 'increase',
    'v': 1,
    'player': player,
    'tier': tier,
    'game_epoch': gameEpoch,
    'additional_lamports_per_number': additionalLamportsPerNumber,
    'choice': choice,
  });
}
