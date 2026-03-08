import 'dart:ui';

import 'package:iseefortune_flutter/api/claim.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/solana/signing/tx_router.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:solana/solana.dart';

/// Thin service:
/// - buildClaim(): calls your build-claim endpoint (returns payout + unsigned msg)
/// - claim(): signs+sends a prebuilt message (or builds if not provided)
class ClaimTxService {
  ClaimTxService({required this.walletProvider, required this.buildClaimTx, required this.txRouter});

  final WalletProvider walletProvider;

  /// Your HTTP call:
  /// POST /claim/build  => includes messageB64 + payoutLamports etc.
  final Future<BuildClaimResponse> Function({required String claimer, required String predictionPda})
  buildClaimTx;

  final TxRouter txRouter;

  /// Build (prefetch) claim payload so UI can:
  /// - show payout instantly
  /// - enable claim immediately
  Future<BuildClaimResponse> buildClaim(String predictionPda) async {
    final claimer = walletProvider.pubkey;
    if (claimer == null) throw StateError('No wallet connected');

    icLogger.i('[claimTx] buildClaim predictionPda=$predictionPda claimer=$claimer');
    return buildClaimTx(claimer: claimer, predictionPda: predictionPda);
  }

  /// Claim using a prebuilt payload (preferred), otherwise build internally.
  ///
  /// Notes:
  /// - We retry ONCE if the blockhash is expired by rebuilding.
  /// - We surface UserCancelledSigning for the provider to reset state.
  Future<String> claim(
    String predictionPda, {
    BuildClaimResponse? built,
    VoidCallback? onAwaitingSignature,
    Commitment commitment = Commitment.confirmed,
    bool skipPreflight = false,
    int maxSendRetries = 2,
  }) async {
    final claimer = walletProvider.pubkey;
    if (claimer == null) throw StateError('No wallet connected');

    icLogger.i('[claimTx] claim predictionPda=$predictionPda claimer=$claimer built=${built != null}');

    Future<String> signSendConfirm(BuildClaimResponse payload) async {
      icLogger.i('[claimTx] open wallet signing UI…');
      onAwaitingSignature?.call();

      icLogger.i('[claimTx] sign+send+confirm…');
      final sig = await txRouter.signSendAndConfirm(
        messageB64: payload.messageB64,
        transactionB64: payload.transactionB64,
        commitment: commitment,
        skipPreflight: skipPreflight,
        maxRetries: maxSendRetries,
      );

      icLogger.i('[claimTx] confirmed sig=$sig');
      return sig;
    }

    Future<BuildClaimResponse> buildFresh() async {
      icLogger.i('[claimTx] build unsigned tx…');
      return buildClaimTx(claimer: claimer, predictionPda: predictionPda);
    }

    try {
      // 1) Use prebuilt if provided, else build.
      final payload = built ?? await buildFresh();
      return await signSendConfirm(payload);
    } catch (e) {
      icLogger.w('[claimTx] attempt failed: $e');

      if (_looksLikeUserCancelled(e)) {
        icLogger.i('[claimTx] user cancelled signing');
        throw UserCancelledSigning();
      }

      // 2) If blockhash is expired, rebuild and try once more.
      if (_looksLikeExpiredBlockhash(e)) {
        icLogger.i('[claimTx] retrying due to expired blockhash… (rebuild)');
        final rebuilt = await buildFresh();
        return await signSendConfirm(rebuilt);
      }

      rethrow;
    }
  }
}

bool _looksLikeExpiredBlockhash(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('blockhash not found') ||
      s.contains('blockhashnotfound') ||
      s.contains('transactionexpired') ||
      s.contains('block height exceeded') ||
      (s.contains('expired') && s.contains('blockhash'));
}

class UserCancelledSigning implements Exception {
  @override
  String toString() => 'UserCancelledSigning';
}

bool _looksLikeUserCancelled(Object e) {
  final s = e.toString().toLowerCase();

  // Seed Vault cancel/dismiss pattern
  if (s.contains('actionfailedexception') && s.contains('signmessages') && s.contains('result=0')) {
    return true;
  }

  // Generic wallet cancel vibes (fallback)
  if (s.contains('cancel') || s.contains('canceled') || s.contains('cancelled')) return true;
  if (s.contains('user rejected')) return true;
  if (s.contains('declined') || s.contains('denied')) return true;
  if (s.contains('aborted')) return true;

  return false;
}
