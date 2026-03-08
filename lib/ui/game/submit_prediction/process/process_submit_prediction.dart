import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/api/place_prediction.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/providers/predictions_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_pda_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_predictions_provider.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/solana/signing/tx_router.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:provider/provider.dart';

// Put this near the file top (or bottom) — private cancel signal.
class _UserCancelledSigning implements Exception {
  const _UserCancelledSigning();
  @override
  String toString() => 'User cancelled signing';
}

bool _isSeedVaultCancel(Object e) {
  final s = e.toString();
  return s.contains('signMessages failed with result=0') ||
      (s.contains('ActionFailedException') && s.contains('result=0')) ||
      s.contains('result=0');
}

VoidCallback? processSubmitPrediction(
  BuildContext context,
  int step,
  SubmitPredictionState s, {
  required String? selectionError,
  required bool hasEnoughBalance,
  required int selectionCount,
}) {
  if (s.isSubmitting) return null;

  if (step == 0) {
    if (selectionError != null) return null;
    if (s.action == PredictionAction.changeNumber && !changedSelection(s)) return null;
    return s.nextStep;
  }

  if (!hasEnoughBalance || selectionCount == 0) return null;

  return () async {
    final state = context.read<SubmitPredictionState>();

    final walletConn = context.read<WalletConnectionProvider>();
    final player = walletConn.pubkey;
    if (player == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Connect a wallet first')));
      return;
    }

    final tier = context.read<TierProvider>().tier;
    final lf = context.read<LiveFeedProvider>().liveFeed;
    if (lf == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Game data not ready yet')));
      return;
    }

    try {
      final sig = await state.runSubmitting<String>(() async {
        final payload = state.toPayload(
          playerWalletPubkey: player,
          tier: tier,
          gameEpoch: lf.firstEpochInChain.toString(),
        );

        final resp = await buildUnsignedPredictionMessage(payload);
        final txRouter = context.read<TxRouter>();

        try {
          // Must return String on success
          return await txRouter.signSendAndConfirm(
            messageB64: resp.messageB64,
            transactionB64: resp.transactionB64,
          );
        } catch (e) {
          // User closed sheet = cancel, not failure
          if (_isSeedVaultCancel(e)) {
            throw const _UserCancelledSigning();
          }
          rethrow;
        }
      });

      icLogger.i('Prediction submitted sig=$sig');

      // Post-tx resync
      final profilePda = context.read<ProfilePdaProvider>();
      await profilePda.refetchNow(commitment: 'confirmed');

      unawaited(context.read<PlayerPredictionsProvider>().refresh(force: true));

      // Reload, awaited, so Countdown is updated before modal closes
      await context.read<PredictionsProvider>().forceReload();

      final live = context.read<PredictionsProvider>();
      icLogger.i('[SubmitPrediction] after reload myPred=${live.myPredictionForPlayer(player) != null}');

      // Grab messenger BEFORE popping the modal route.
      final messenger = ScaffoldMessenger.of(context);

      final successMsg = switch (state.action) {
        PredictionAction.place => 'Your prediction has been successfully set',
        PredictionAction.increase =>
          'Position increased by ${state.amountSol.toStringAsFixed(2)} SOL per number',
        PredictionAction.changeNumber => 'Your prediction has been updated',
      };

      final successColor = switch (state.action) {
        PredictionAction.place => Colors.green.withOpacityCompat(0.90),
        PredictionAction.increase => Colors.blue.withOpacityCompat(0.88),
        PredictionAction.changeNumber => Colors.purple.withOpacityCompat(0.88),
      };

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(successMsg),
            duration: const Duration(seconds: 3),
            backgroundColor: successColor,
            behavior: SnackBarBehavior.fixed,
          ),
        );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Cancel path: no scary logs, no error snackbar
      if (e is _UserCancelledSigning) {
        icLogger.i('[SubmitPrediction] user cancelled signing');
        return;
      }

      icLogger.e('Submit failed: $e');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Submit failed: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.fixed, // ✅ keep consistent
          ),
        );
    }
  };
}
