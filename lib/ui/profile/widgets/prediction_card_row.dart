import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class PredictionCardRow extends StatefulWidget {
  const PredictionCardRow({super.key, required this.row, this.onViewArweave, required this.onCopyPda});

  final ProfilePredictionRowVM row;
  final VoidCallback? onViewArweave;
  final VoidCallback onCopyPda;

  @override
  State<PredictionCardRow> createState() => _PredictionCardRowState();
}

class _PredictionCardRowState extends State<PredictionCardRow> with TickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacityCompat(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacityCompat(0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    children: [
                      // Left number badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: r.core.badgeColor.withOpacityCompat(0.22),
                          border: Border.all(color: r.core.badgeColor.withOpacityCompat(0.55)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${r.core.pick}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.titleLine,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              r.core.timeLine,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            r.core.amountText,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.statusText,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: r.statusColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Smooth expand/collapse (better than AnimatedCrossFade here)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _open ? 1.0 : 0.0,
                    child: _ExpandedDetails(
                      predictionPdaShort: r.core.predictionPdaShort,
                      winningNumberText: '${r.winningNumber ?? '—'}',
                      totalPotText: r.totalPotText,
                      ticketsEarnedText: '${r.ticketsEarned}',
                      arweaveHasUrl: r.arweaveUrl != null,
                      onCopyPda: widget.onCopyPda,
                      onViewArweave: widget.onViewArweave,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({
    required this.predictionPdaShort,
    required this.winningNumberText,
    required this.totalPotText,
    required this.ticketsEarnedText,
    required this.arweaveHasUrl,
    required this.onCopyPda,
    required this.onViewArweave,
  });

  final String predictionPdaShort;
  final String winningNumberText;
  final String totalPotText;
  final String ticketsEarnedText;
  final bool arweaveHasUrl;
  final VoidCallback onCopyPda;
  final VoidCallback? onViewArweave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacityCompat(0.22),
        border: Border(top: BorderSide(color: Colors.white.withOpacityCompat(0.08))),
      ),
      child: Column(
        children: [
          _kv(
            context,
            'Prediction PDA',
            predictionPdaShort,
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: onCopyPda,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          _kv(context, 'Winning Number', winningNumberText),
          _kv(context, 'Total Pot', totalPotText),
          _kv(context, 'Tickets Earned', ticketsEarnedText),
          _kv(
            context,
            'Arweave Proof',
            arweaveHasUrl ? 'View' : '—',
            trailing: arweaveHasUrl
                ? TextButton(
                    onPressed: onViewArweave,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View'),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {Widget? trailing}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }
}
