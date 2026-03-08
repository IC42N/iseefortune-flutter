import 'package:iseefortune_flutter/utils/solana/json_rpc.dart';

class RpcAccount {
  RpcAccount({required this.pubkey, required this.dataBase64, required this.owner, required this.lamports});

  final String pubkey;
  final String dataBase64; // raw account data (base64)
  final String owner;
  final int lamports;
}

Future<void> getMultipleAccountsChunkedEach(
  List<String> pubkeys, {
  int chunkSize = 20,
  String commitment = 'confirmed',
  String? tag,
  required Future<void> Function(List<RpcAccount> chunkAccounts) onChunk,
}) async {
  for (var i = 0; i < pubkeys.length; i += chunkSize) {
    final chunk = pubkeys.sublist(i, (i + chunkSize > pubkeys.length) ? pubkeys.length : i + chunkSize);

    final result = await JsonRpcRaw.call(
      'getMultipleAccounts',
      tag: tag ?? 'getMultipleAccounts',
      params: [
        chunk,
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    final values = (result as Map<String, dynamic>)['value'] as List<dynamic>;
    final accounts = <RpcAccount>[];

    for (var j = 0; j < values.length; j++) {
      final v = values[j];
      if (v == null) continue;

      final m = v as Map<String, dynamic>;
      final data = (m['data'] as List).first as String;

      accounts.add(
        RpcAccount(
          pubkey: chunk[j],
          dataBase64: data,
          owner: m['owner'] as String,
          lamports: (m['lamports'] as num).toInt(),
        ),
      );
    }

    await onChunk(accounts); // ✅ UI can update here
  }
}

Future<List<RpcAccount>> getMultipleAccountsChunked(
  List<String> pubkeys, {
  int chunkSize = 20,
  String commitment = 'confirmed',
  String? tag,
}) async {
  final out = <RpcAccount>[];

  for (var i = 0; i < pubkeys.length; i += chunkSize) {
    final chunk = pubkeys.sublist(i, (i + chunkSize > pubkeys.length) ? pubkeys.length : i + chunkSize);

    final result = await JsonRpcRaw.call(
      'getMultipleAccounts',
      tag: tag ?? 'getMultipleAccounts',
      params: [
        chunk,
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    final values = (result as Map<String, dynamic>)['value'] as List<dynamic>;

    for (var j = 0; j < values.length; j++) {
      final v = values[j];
      if (v == null) continue;

      final m = v as Map<String, dynamic>;
      final data = (m['data'] as List).first as String; // ["base64...", "base64"]
      out.add(
        RpcAccount(
          pubkey: chunk[j],
          dataBase64: data,
          owner: m['owner'] as String,
          lamports: (m['lamports'] as num).toInt(),
        ),
      );
    }
  }

  return out;
}
