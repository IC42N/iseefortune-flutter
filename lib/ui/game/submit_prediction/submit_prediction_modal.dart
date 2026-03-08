import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/steps/step_manage_prediction.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/widgets/footer_controls.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/steps/step_amount_and_submit.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/steps/step_choose_selection.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/widgets/step_header.dart';
import 'package:iseefortune_flutter/ui/shared/countdown_bet_cutoff.dart';
import 'package:iseefortune_flutter/ui/shared/light_divider.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

class SubmitPredictionModal extends StatelessWidget {
  const SubmitPredictionModal({
    super.key,
    required this.action,
    required this.entry,
    this.initialNumbers,
    this.initialLamportsPerNumber,
  });

  final PredictionAction action;
  final SubmitModalEntry entry;
  final Uint8List? initialNumbers;
  final BigInt? initialLamportsPerNumber;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SubmitPredictionState()
        ..open(
          entry: entry,
          action: action,
          initialNumbers: initialNumbers,
          initialLamportsPerNumber: initialLamportsPerNumber,
        ),
      child: const _SubmitPredictionBody(),
    );
  }
}

class _SubmitPredictionBody extends StatelessWidget {
  const _SubmitPredictionBody();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SubmitPredictionState>();
    final step = context.select<SubmitPredictionState, int>((s) => s.step);
    final showBack = step == 1 || (step == 0 && s.fromManageToChange);
    final subtitleStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 10,
      height: 1.0,
      fontWeight: FontWeight.w800,
      color: Colors.white.withOpacityCompat(0.72),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
      child: Stack(
        children: [
          // Main content column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacityCompat(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              StepHeader(step: step),
              const SizedBox(height: 12),
              BetCutoffText(compact: true, style: subtitleStyle),

              const SizedBox(height: 16),
              LightDivider(inset: 6, opacity: 0.10),
              const SizedBox(height: 16),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (step) {
                  0 =>
                    s.isManageEntry
                        ? const StepManagePrediction(key: ValueKey('manage0'))
                        : const StepChooseSelection(key: ValueKey('step0')),
                  _ => const StepAmountAndSubmit(key: ValueKey('step1')),
                },
              ),

              FooterControls(step: step),
            ],
          ),

          // Overlay back arrow (only on step 1)
          if (showBack)
            Positioned(
              left: 0,
              top: -5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: s.isSubmitting
                    ? null
                    : () {
                        if (step == 1) {
                          context.read<SubmitPredictionState>().prevStep();
                        } else {
                          // step == 0 and fromManageToChange
                          context.read<SubmitPredictionState>().backToManage();
                        }
                      },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Colors.white.withOpacityCompat(s.isSubmitting ? 0.12 : 0.35),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
