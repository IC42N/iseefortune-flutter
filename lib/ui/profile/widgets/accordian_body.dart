import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/providers/claim/claim_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_predictions_provider.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/detail_grid.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/ticket_banner.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/winner_banner.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/solana/pubkey.dart';
import 'package:provider/provider.dart';

class ExpandedBody extends StatelessWidget {
  const ExpandedBody({super.key, required this.row});
  final ProfilePredictionRowVM row;

  static Future<void> _onClaim(BuildContext context, ProfilePredictionRowVM row) async {
    final pda = row.core.pda;

    final predProv = context.read<PlayerPredictionsProvider>();
    final claimProv = context.read<ClaimProvider>();

    icLogger.i(
      '[profileClaim] tap pda=$pda tier=${row.tier} firstEpoch=${row.gameEpoch} canClaim=${row.canClaim}',
    );

    if (claimProv.isClaiming(pda)) {
      icLogger.i('[profileClaim] ignore (already claiming) pda=$pda');
      return;
    }

    final sig = await claimProv.claimForPredictionPDA(row.core.pda);

    if (sig == null) {
      final st = claimProv.stateFor(pda);
      if (!st.isError) {
        icLogger.i('[profileClaim] no-op (likely cancelled) pda=$pda phase=${st.phase}');
        return;
      }

      final msg = st.errorMessage ?? 'Claim failed.';
      icLogger.w('[profileClaim] failed pda=$pda msg="$msg"');

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(behavior: SnackBarBehavior.fixed, content: Text(msg)));
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (!context.mounted) return;
        icLogger.i('[profileClaim] clear error state pda=$pda');
        context.read<ClaimProvider>().clear(pda);
      });

      return;
    }

    icLogger.i('[profileClaim] success pda=$pda sig=$sig -> disable row');
    final updated = row.copyWith(isClaimed: true, canClaim: false, claimedAt: DateTime.now());
    predProv.upsertRowOverrideForPda(pda, updated);
    claimProv.clear(pda);
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = row.outcome == PredictionOutcome.correct;
    final receivedTicket = row.ticketsEarned > 0;
    final claimProv = context.watch<ClaimProvider>();
    final claimState = claimProv.stateFor(row.core.pda);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCorrect) ...[
          WinBanner(
            percentOfPotText: row.percentOfPotText ?? '—',
            payoutLabel: row.payoutText,
            claimState: claimState,
            isClaimedOverride: row.isClaimed,
            claimedAtOverride: row.claimedAt,
            onClaim: row.canClaim ? () => _onClaim(context, row) : null,
          ),
        ],
        if (receivedTicket) ...[TicketBanner(ticketsEarned: row.ticketsEarned)],
        DetailGrid(
          pdaShort: shortPDA(row.core.pda),
          onCopyPda: () => Clipboard.setData(ClipboardData(text: row.core.pda)),
          winningNumber: row.winningNumber?.toString() ?? '—',
          totalPot: row.totalPotText,
          arweaveUrl: row.arweaveUrl,
        ),
      ],
    );
  }
}
