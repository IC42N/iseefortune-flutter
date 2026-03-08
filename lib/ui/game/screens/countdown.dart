import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_model.dart';
import 'package:iseefortune_flutter/providers/predictions_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/ui/game/player_box/my_prediction_summary.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/open_submit_prediciton_modal.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/how_to_play/how_to_play.dart';
import 'package:iseefortune_flutter/ui/shared/connect_wallet_sheet.dart';
import 'package:iseefortune_flutter/ui/shared/floaty.dart';
import 'package:iseefortune_flutter/ui/game/countdown/help_pill_button.dart';
import 'package:iseefortune_flutter/ui/shared/slide_arrow_hint.dart';
import 'package:provider/provider.dart';
import 'package:iseefortune_flutter/providers/bet_cutoff_provider.dart';
import 'package:iseefortune_flutter/ui/game/countdown/epoch_progress.dart';
import 'package:iseefortune_flutter/ui/game/player_box/player_box.dart';

class CountdownPage extends StatelessWidget {
  const CountdownPage({super.key, required this.ringValue});
  final ValueNotifier<double> ringValue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Helper button on top here.
        Positioned(
          top: 18,
          left: 0,
          right: 0,
          child: Center(
            child: Floaty(child: HelpPillButton(onTap: () => HowToPlayModal.show(context))),
          ),
        ),

        const Align(
          alignment: Alignment(0, -0.30), // move up slightly
          child: EpochProgress(size: 340, strokeWidth: 20),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 74),
            child: SizedBox(
              width: double.infinity,

              child: Builder(
                builder: (context) {
                  final connected = context.select<WalletConnectionProvider, bool>((p) => p.isConnected);
                  final pubkey = context.select<WalletConnectionProvider, String?>((p) => p.pubkey);
                  final isConnecting = context.select<WalletConnectionProvider, bool>((p) => p.isConnecting);
                  final bettingOpen = context.select<BetCutoffProvider, bool>((p) => p.bettingOpen);
                  final myPred = (connected && pubkey != null)
                      ? context.select<PredictionsProvider, PredictionModel?>(
                          (p) => p.myPredictionForPlayer(pubkey),
                        )
                      : null;

                  final PlayerBoxState state = !connected
                      ? PlayerBoxState.disconnected
                      : (myPred == null ? PlayerBoxState.connectedNoBet : PlayerBoxState.connectedHasBet);

                  final summary = myPred == null ? null : buildMyPredictionSummary(myPred);

                  return PlayerBox(
                    state: state,
                    onConnect: (!connected && !isConnecting) ? () => showConnectWalletSheet(context) : null,
                    onPlaceBet: (connected && bettingOpen && myPred == null)
                        ? () => openSubmitPredictionModal(context, action: PredictionAction.place)
                        : null,
                    onManageBet: myPred == null
                        ? null
                        : () => openSubmitPredictionModal(
                            context,
                            action: PredictionAction.increase, // placeholder default
                            entry: SubmitModalEntry.manage,
                            initialSelections: myPred.selections,
                            initialLamportsPerNumber: myPred.lamportsPerNumber,
                          ),
                    predictionLabel: summary?.predictionLabel,
                    selections: summary?.selections,
                    amountLabel: summary?.amountLabel,
                  );
                },
              ),
            ),
          ),
        ),

        // Slide hint (right edge)
        const Positioned(right: 6, top: 0, bottom: 90, child: SlideHint()),
      ],
    );
  }
}
