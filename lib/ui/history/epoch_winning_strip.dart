import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:iseefortune_flutter/providers/game_history_provider.dart';

class EpochWinningStrip extends StatelessWidget {
  const EpochWinningStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = context.select<GameHistoryProvider, List>((p) => p.winningHistory);
    final selected = context.select<GameHistoryProvider, BigInt?>((p) => p.selectedEpoch);

    if (rows.isEmpty) {
      return const SizedBox(height: 56);
    }

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final r = rows[i] as dynamic; // quick to avoid importing model here
          final epoch = r.epoch as BigInt;
          final win = r.winningNumber as int;
          final isSel = selected == epoch;

          return GestureDetector(
            onTap: () => context.read<GameHistoryProvider>().selectEpoch(epoch),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSel ? Colors.white.withOpacityCompat(0.14) : Colors.white.withOpacityCompat(0.06),
                border: Border.all(color: Colors.white.withOpacityCompat(isSel ? 0.22 : 0.10), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'E ${epoch.toString()}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacityCompat(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('$win', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
