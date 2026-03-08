// lib/api/tx_builder_api.dart
import 'package:iseefortune_flutter/api/api_client.dart';
import 'package:iseefortune_flutter/api/models/build_message_response.dart';

class TxBuilderApi {
  TxBuilderApi({
    required ApiClient api,
    required String buildPath, // e.g. '/prediction/tx/build' or '/claim/tx/build'
    String? apiKey,
  }) : _api = api,
       _buildPath = buildPath,
       _apiKey = apiKey;

  final ApiClient _api;
  final String _buildPath;
  final String? _apiKey;

  Future<BuildMessageResponse> buildUnsignedMessage(Map<String, dynamic> payload) {
    return _api.postJson(
      _buildPath,
      headers: {if (_apiKey != null && _apiKey.isNotEmpty) 'x-api-key': _apiKey},
      body: payload,
      parser: (json) => BuildMessageResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}
