import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/widgets/bump_button.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/widgets/selection_numbers.dart';
import 'package:iseefortune_flutter/ui/shared/light_divider.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/amount_step_helpers.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';
import 'package:provider/provider.dart';

class StepAmountAndSubmit extends StatelessWidget {
  const StepAmountAndSubmit({super.key});

  static const double _kStepSol = 0.01;

  static double _floorToStep(double v, double step) {
    if (step <= 0) return v;
    return (v / step).floor() * step;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SubmitPredictionState>();
    final wallet = context.watch<WalletProvider>();
    final tierId = context.watch<TierProvider>().tier;
    final cfg = context.watch<ConfigProvider>();

    const eps = 1e-9;

    final isChange = s.action == PredictionAction.changeNumber;
    final isIncrease = s.action == PredictionAction.increase;

    // Tier bounds (fallbacks)
    final tierMinSol = cfg.tierMinSol(tierId) ?? 0.01;
    final tierMaxSol = cfg.tierMaxSol(tierId) ?? 0.50;

    // Wallet balance
    final walletBalanceSol = wallet.solBalance ?? 0.0;

    // Selections
    final selections = selectionNumbers(context, s);

    // Count rules:
    // - Increase: count should always be the original locked count
    final selectionCount = isIncrease
        ? (s.baseSelectionCount > 0 ? s.baseSelectionCount : s.numbers.length)
        : s.numbers.length;

    // Fee estimate
    const feeBufferLamports = 50_000;
    final feeSol = feeBufferLamports / 1e9;

    // What user pays NOW:
    // - Place: count * perNumber
    // - Increase: count * additional
    // - Change: no wager, fees only
    final perNumberDueNowSol = isChange ? 0.0 : s.amountSol;
    final wagerDueNowSol = selectionCount * perNumberDueNowSol;
    final totalWithFeeSol = wagerDueNowSol + feeSol;

    final hasEnoughBalance = walletBalanceSol >= totalWithFeeSol;

    // ----------------------------
    // Slider max (snapped to step)
    // ----------------------------
    // Wallet cap should respect fees: (balance - fee) / count
    // If count==0, keep it usable but it won't submit anyway.
    final maxByBalanceRaw = (selectionCount > 0)
        ? ((walletBalanceSol - feeSol) / selectionCount)
        : tierMaxSol;

    final maxByBalance = math.max(0.0, maxByBalanceRaw);

    // For increase: additional <= tierMax - base
    final maxByTierForIncrease = isIncrease ? (tierMaxSol - s.baseAmountSol) : tierMaxSol;

    // Raw max before snapping
    final rawEffectiveMax = isIncrease
        ? math.min(maxByBalance, maxByTierForIncrease)
        : math.min(maxByBalance, tierMaxSol);

    // Snap DOWN to step so slider max is always on a 0.01 boundary.
    final snappedMax = _floorToStep(rawEffectiveMax, _kStepSol);

    // Keep slider sane: ensure max >= min (or it will be locked)
    final effectiveMax = math.max(tierMinSol, snappedMax);

    // Slider should only be interactive if there is actual range
    final sliderEnabled = !isChange && !s.isSubmitting && (effectiveMax - tierMinSol) > eps;

    // Clamp only when slider visible
    if (!isChange) {
      // Always keep display value clamped for rendering
      final clamped = clamp(s.amountSol, tierMinSol, effectiveMax);

      // NEVER auto-adjust the user's amount during submit (prevents 100% jump)
      if (!s.isSubmitting) {
        // Only force-set when the value is truly out of bounds (tier/balance changed)
        if ((clamped - s.amountSol).abs() > eps) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            s.setAmountSol(clamped);
          });
        }
      }
    }

    final divisions = divisionsForStep(tierMinSol, effectiveMax, _kStepSol);

    final canMinus = sliderEnabled && (s.amountSol - _kStepSol) >= (tierMinSol - eps);
    final canPlus = sliderEnabled && (s.amountSol + _kStepSol) <= (effectiveMax + eps);

    // IMPORTANT: keep all derived displays aligned to step rounding
    final addPerNumberSol = roundToStep(s.amountSol);

    // For increase: "new wager per number" after applying additional
    final newPerNumberAfterIncreaseSol = s.baseAmountSol + addPerNumberSol;

    // Header label/value
    final headerLabel = isIncrease ? 'Increase (per number)' : 'Amount (per number)';
    final headerValue = '${addPerNumberSol.toStringAsFixed(2)} SOL';

    // Optional: explain why slider is locked
    String? lockedReason;
    if (!isChange && !sliderEnabled) {
      if (isIncrease && (maxByTierForIncrease <= tierMinSol + eps)) {
        lockedReason = 'Already at tier max.';
      } else if (maxByBalance <= tierMinSol + eps) {
        lockedReason = 'Balance caps this amount.';
      } else {
        lockedReason = 'Max reached.';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Slider block (hidden for change-number)
        if (!isChange) ...[
          Row(
            children: [
              Text(
                headerLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withOpacityCompat(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                headerValue,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withOpacityCompat(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              BumpButton(
                icon: Icons.remove_rounded,
                enabled: canMinus,
                onTap: () {
                  final next = roundToStep(clamp(s.amountSol - _kStepSol, tierMinSol, effectiveMax));
                  s.setAmountSol(next);
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    inactiveTrackColor: Colors.white.withOpacityCompat(0.08),
                    activeTrackColor: AppColors.goldColor.withOpacityCompat(0.6),
                    thumbColor: AppColors.goldColor,
                    overlayColor: AppColors.goldColor.withOpacityCompat(0.15),

                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),

                    tickMarkShape: SliderTickMarkShape.noTickMark, // cleaner
                    activeTickMarkColor: Colors.transparent,
                    inactiveTickMarkColor: Colors.transparent,
                  ),
                  child: Slider(
                    value: clamp(s.amountSol, tierMinSol, effectiveMax),
                    min: tierMinSol,
                    max: effectiveMax,
                    divisions: divisions,
                    onChanged: sliderEnabled ? (v) => s.setAmountSol(roundToStep(v)) : null,
                  ),
                ),
              ),
              BumpButton(
                icon: Icons.add_rounded,
                enabled: canPlus,
                onTap: () {
                  final next = roundToStep(clamp(s.amountSol + _kStepSol, tierMinSol, effectiveMax));
                  s.setAmountSol(next);
                },
              ),
            ],
          ),

          if (lockedReason != null) ...[
            const SizedBox(height: 6),
            Text(
              lockedReason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacityCompat(0.55),
              ),
            ),
          ],

          const SizedBox(height: 10),
          LightDivider(inset: 6, opacity: 0.10),
          const SizedBox(height: 16),
        ],

        // Breakdown
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            selections,
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isChange
                      ? '$selectionCount number${selectionCount == 1 ? '' : 's'} (unchanged)'
                      : '$selectionCount number${selectionCount == 1 ? '' : 's'} × ${addPerNumberSol.toStringAsFixed(2)} SOL',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: Colors.white.withOpacityCompat(0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  'Fees (est.): ${feeSol.toStringAsFixed(5)} SOL',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacityCompat(0.55),
                  ),
                ),
                const SizedBox(height: 3),

                Text(
                  'Total: ${totalWithFeeSol.toStringAsFixed(5)} SOL',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.goldColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Wallet balance: ${formatSol(walletBalanceSol)} SOL',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasEnoughBalance
                          ? Colors.white.withOpacityCompat(0.55)
                          : Colors.redAccent.withOpacityCompat(0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Only extra line for increase: show new per-number after increase
        if (isIncrease) ...[
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppColors.goldColor.withOpacityCompat(0.06),
              border: Border.all(color: AppColors.goldColor.withOpacityCompat(0.18)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: AppColors.goldColor.withOpacityCompat(0.75),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectionCount == 1
                        ? 'After increase: ${formatSol(newPerNumberAfterIncreaseSol)} SOL'
                        : 'After increase: ${formatSol(newPerNumberAfterIncreaseSol)} SOL / number',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacityCompat(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
