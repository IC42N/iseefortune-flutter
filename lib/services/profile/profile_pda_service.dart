// lib/services/profile/profile_pda_service.dart
import 'dart:typed_data';

import 'package:iseefortune_flutter/solana/decode/decode_profile.dart';
import 'package:iseefortune_flutter/solana/pdas.dart';
import 'package:iseefortune_flutter/solana/service/websocket.dart';
import 'package:iseefortune_flutter/solana/decode/account_bytes.dart';
import 'package:iseefortune_flutter/solana/decode/extract_base64.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/solana/json_rpc.dart';
import 'package:iseefortune_flutter/models/profile/profile_pda_model.dart';

class ProfilePdaService {
  ProfilePdaService(this._ws);

  final SolanaWsService _ws;

  Future<PlayerProfilePDAModel?> fetchProfileByWalletPubkey(
    String walletPubkey, {
    String commitment = 'confirmed',
  }) async {
    final profilePda = await AppPdas.playerProfilePda(walletPubkey);
    return fetchProfileByPda(profilePda, commitment: commitment);
  }

  Future<PlayerProfilePDAModel?> fetchProfileByPda(
    String profilePda, {
    String commitment = 'confirmed',
  }) async {
    final base64Str = await fetchAccountBase64OrNull(profilePda, commitment: commitment);
    if (base64Str == null) return null;

    final Uint8List bytes = accountBytesFromBase64(base64Str);
    return decodePlayerProfile(bytes);
  }

  Future<String?> fetchAccountBase64OrNull(String pubkey, {String commitment = 'confirmed'}) async {
    final result = await JsonRpcRaw.call(
      'getAccountInfo',
      params: [
        pubkey,
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    final value = result?['value'];
    if (value == null) return null; // Expected for brand new players

    final data = value['data'];
    return extractBase64FromAccountData(data, label: 'Profile($pubkey)');
  }

  Stream<PlayerProfilePDAModel> subscribeProfileByWalletPubkey(
    String walletPubkey, {
    String commitment = 'confirmed',
  }) async* {
    final profilePda = await AppPdas.playerProfilePda(walletPubkey);
    yield* subscribeProfileByPda(profilePda, commitment: commitment);
  }

  Stream<PlayerProfilePDAModel> subscribeProfileByPda(
    String profilePda, {
    String commitment = 'confirmed',
  }) async* {
    yield* _ws
        .accountSubscribe(profilePda, encoding: 'base64', commitment: commitment)
        .where((v) => v != null)
        .map((v) {
          final data = v!['data'];
          final base64Str = extractBase64FromAccountData(data, label: 'ProfileWS($profilePda)');

          icLogger.d('[ProfilePdaService] WS pda=$profilePda b64Len=${base64Str.length}');

          final Uint8List bytes = accountBytesFromBase64(base64Str);

          icLogger.d(
            '[ProfilePdaService] WS rawLen=${bytes.length} bodyLen=${bytes.length >= 8 ? (bytes.length - 8) : -1}',
          );

          return decodePlayerProfile(bytes);
        });
  }

  Future<String> fetchAccountBase64(String pubkey, {String commitment = 'confirmed'}) async {
    final result = await JsonRpcRaw.call(
      'getAccountInfo',
      params: [
        pubkey,
        {'encoding': 'base64', 'commitment': commitment},
      ],
    );

    final value = result?['value'];
    if (value == null) {
      throw Exception('Profile PDA account not found: $pubkey');
    }

    final data = value['data'];
    return extractBase64FromAccountData(data, label: 'Profile($pubkey)');
  }
}
