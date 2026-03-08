import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/process/process_submit_prediction.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

class FooterControls extends StatelessWidget {
  const FooterControls({super.key, required this.step});
  final int step;

  // Safety buffer for fees / rent / priority fees etc.
  // 50,000 lamports = 0.00005 SOL
  static const int _kFeeBufferLamports = 300_000;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SubmitPredictionState>();

    // If we're on manage entry and step 0 is the manage screen,
    // don't show the global footer button (manage screen has its own CTAs).
    if (step == 0 && s.isManageEntry) {
      return const SizedBox.shrink();
    }

    final wallet = context.watch<WalletProvider>();

    // Step 0: selection gate
    final selectionErr = (step == 0) ? s.selectionError : null;

    // Balance gate (all in lamports as int)
    final selectionCount = s.numbers.length;

    // per-number wager in lamports (rounded)
    final perNumberLamports = (s.amountSol * 1e9).round();

    // total = count * perNumber
    final totalWagerLamports = selectionCount * perNumberLamports;

    // wallet balance in lamports
    final balanceLamports = wallet.lamports ?? 0;

    // add buffer for fees / rent / priority fees
    final feeBuffer = _kFeeBufferLamports;
    final requiredLamports = switch (s.action) {
      PredictionAction.place => totalWagerLamports + feeBuffer,
      PredictionAction.increase => totalWagerLamports + feeBuffer, // additional only
      PredictionAction.changeNumber => feeBuffer, // only fees
    };

    // Only enforce on wager/review screen (step == 1)
    final hasEnoughBalance = (step == 1) ? (balanceLamports >= requiredLamports) : true;

    final balanceIsZero = (step == 1) && (balanceLamports <= 0);

    final balanceErr = (step == 1 && selectionCount > 0 && !hasEnoughBalance)
        ? (balanceIsZero ? 'No balance' : 'Insufficient balance')
        : null;

    final err = selectionErr ?? balanceErr;

    final onPressed = processSubmitPrediction(
      context,
      step,
      s,
      selectionError: selectionErr,
      hasEnoughBalance: hasEnoughBalance,
      selectionCount: selectionCount,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Column(
          children: [
            if (step > 0) const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                // Slightly dull when disabled (null onPressed)
                backgroundColor: AppColors.goldColor.withOpacityCompat(onPressed == null ? 0.45 : 0.95),
                foregroundColor: Colors.black.withOpacityCompat(onPressed == null ? 0.55 : 1.0),
              ),
              child: Text(_primaryLabel(step, s, err), textAlign: TextAlign.center),
            ),
          ],
        ),
      ],
    );
  }

  String _primaryLabel(int step, SubmitPredictionState s, String? err) {
    if (s.isSubmitting) return 'Submitting…';
    if (err != null) return err;

    if (step == 0) {
      if (s.action == PredictionAction.changeNumber) {
        // If unchanged, prompt user (button will be disabled by _primaryAction).
        if (!changedSelection(s)) return 'Select your new prediction';
        return 'Continue';
      }
      return 'Continue';
    }

    if (s.action == PredictionAction.changeNumber) return 'Confirm change';
    if (s.action == PredictionAction.increase) return 'Submit increase';
    return 'Submit';
  }
}
