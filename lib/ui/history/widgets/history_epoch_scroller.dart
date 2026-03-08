// lib/ui/history/widgets/history_epoch_scroller.dart
import 'package:flutter/material.dart';

import 'package:iseefortune_flutter/models/winning_history_row.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

/// Top horizontal scroller that shows epochs + winning numbers.
/// - Pure widget: no provider usage inside.
/// - Caller passes rows + selection + callbacks.
class HistoryEpochScroller extends StatelessWidget {
  const HistoryEpochScroller({
    super.key,
    required this.rows,
    required this.selectedEpoch,
    required this.isLoading,
    required this.error,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<WinningHistoryRow> rows;
  final BigInt? selectedEpoch;
  final bool isLoading;
  final Object? error;
  final ValueChanged<BigInt> onSelect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    // First boot: show a slim loading placeholder so layout is stable.
    if (isLoading && rows.isEmpty) {
      return const SizedBox(height: 50, child: _LoadingSkeletonRow());
    }

    // Empty state (loaded but no data)
    if (!isLoading && rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _EmptyHistoryCard(error: error, onRetry: onRefresh),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(width: 2),
        itemBuilder: (context, i) {
          final r = rows[i];
          final isSelected = selectedEpoch != null && r.epoch == selectedEpoch;
          return _EpochWinTile(
            epoch: r.epoch,
            winningNumber: r.winningNumber,
            isSelected: isSelected,
            onTap: () => onSelect(r.epoch),
          );
        },
      ),
    );
  }
}

class _EpochWinTile extends StatelessWidget {
  const _EpochWinTile({
    required this.epoch,
    required this.winningNumber,
    required this.isSelected,
    required this.onTap,
  });

  final BigInt epoch;
  final int winningNumber;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hue = hueForNumber(winningNumber);
    final pal = RowHuePalette(hue);

    // Web-ish tint palette for the tile background.
    final bg = pal.tintSoft;
    final border = pal.railGlow;
    final accent = pal.pkColor;

    // Winning number pill uses HSV helper used elsewhere in the app.
    final pill = numberColor(winningNumber, intensity: 0.95, saturation: 0.90);
    final pillBorder = numberColorDim(winningNumber, intensity: 0.45);

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 96,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? accent.withOpacityCompat(0.55) : border.withOpacityCompat(0.35),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: [
            isSelected
                ? BoxShadow(color: pal.railGlow.withOpacityCompat(0.36), blurRadius: 6, spreadRadius: 1)
                : BoxShadow(color: pal.railGlow.withOpacityCompat(0.20), blurRadius: 20, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            Text(
              '$epoch',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: Colors.white.withOpacityCompat(0.90),
              ),
            ),

            // Epoch label
            const Spacer(),
            // Winning number pill
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pill.withOpacityCompat(0.24),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: pillBorder.withOpacityCompat(0.45), width: 1),
              ),
              child: Text(
                '$winningNumber',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: pal.pkColor,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error == null ? 'No history yet.' : 'History failed to load.';
    final detail = error?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacityCompat(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Lightweight skeleton row to keep layout stable during first load.
/// (No shimmer dependency; keeps your app lean.)
class _LoadingSkeletonRow extends StatelessWidget {
  const _LoadingSkeletonRow();

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      width: 132,
      height: 94,
      decoration: BoxDecoration(
        color: Colors.white.withOpacityCompat(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
      ),
    );

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => box(),
    );
  }
}
