import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/providers/profile/profile_pda_provider.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/widgets/change_ticket_card.dart';
import 'package:iseefortune_flutter/ui/shared/light_divider.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';
import 'package:provider/provider.dart';

class StepManagePrediction extends StatelessWidget {
  const StepManagePrediction({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SubmitPredictionState>();

    final changeTickets = context.select<ProfilePdaProvider, int>((p) => p.changeTickets);
    final hasChangeTickets = changeTickets > 0;

    final nums = s.sortedNums;
    final amountLabel = formatSol(s.baseAmountSol > 0 ? s.baseAmountSol : s.amountSol);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (nums.isNotEmpty) ...[
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [for (final n in nums) NumberChip(n, size: 40, intensity: 0.9)],
          ),
          const SizedBox(height: 10),
        ],

        Text(
          nums.length == 1 ? '$amountLabel SOL' : '$amountLabel SOL (per number)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacityCompat(0.65),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 12),
        LightDivider(inset: 0, opacity: 0.12),
        const SizedBox(height: 18),

        // POWER ITEM: Change Ticket callout (only when user has at least 1)
        if (hasChangeTickets) ...[
          ChangeTicketCard(count: changeTickets, disabled: s.isSubmitting, onUse: () => s.chooseChange()),
          const SizedBox(height: 18),
        ],

        // Normal action (always available)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: s.isSubmitting ? null : () => s.chooseIncrease(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white.withOpacityCompat(0.85),
              side: BorderSide(color: Colors.white.withOpacityCompat(0.18)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Increase Position'),
          ),
        ),
      ],
    );
  }
}
