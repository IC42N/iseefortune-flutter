import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/game/game_db_model.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

class WinnersTable extends StatelessWidget {
  const WinnersTable({super.key, required this.winners, required this.lamportsToSolText});

  final List<ApiWinnerRow> winners;
  final String Function(BigInt) lamportsToSolText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Player',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Wager',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Text(
                  'Payout',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...winners.map((w) {
            final wagerSol = lamportsToSolTrim(w.wagerWinPortionLamports);
            final payoutSol = lamportsToSolTrim(w.payoutLamports);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      w.player,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      wagerSol,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Text(
                      payoutSol,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
