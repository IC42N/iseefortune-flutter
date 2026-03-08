// lib/api/models/build_message_response.dart
class BuildMessageResponse {
  final bool ok;
  final int v;
  final String action; // optional-ish but useful
  final String messageB64;
  final String recentBlockhash;
  final Map<String, dynamic> accounts;

  BuildMessageResponse({
    required this.ok,
    required this.v,
    required this.action,
    required this.messageB64,
    required this.recentBlockhash,
    required this.accounts,
  });

  factory BuildMessageResponse.fromJson(Map<String, dynamic> json) {
    return BuildMessageResponse(
      ok: json['ok'] == true,
      v: (json['v'] as num?)?.toInt() ?? 0,
      action: (json['action'] as String?) ?? '',
      messageB64: (json['message_b64'] as String?) ?? '',
      recentBlockhash: (json['recent_blockhash'] as String?) ?? '',
      accounts: (json['accounts'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
