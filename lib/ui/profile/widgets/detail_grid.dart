import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/copy_icon.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailGrid extends StatelessWidget {
  const DetailGrid({
    super.key,
    required this.pdaShort,
    required this.onCopyPda,
    required this.winningNumber,
    required this.totalPot,
    required this.arweaveUrl,
  });

  final String pdaShort;
  final VoidCallback onCopyPda;
  final String winningNumber;
  final String totalPot;
  final String? arweaveUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacityCompat(0.20),
        border: Border.all(color: Colors.white.withOpacityCompat(0.06)),
      ),
      child: Column(
        children: [
          _kv(context, 'Prediction PDA', pdaShort, trailing: CopyIcon(onTap: onCopyPda)),
          const SizedBox(height: 4),
          _kv(context, 'Winning Number', winningNumber),
          const SizedBox(height: 4),
          _kv(context, 'Total Pot', totalPot),
          const SizedBox(height: 4),
          _kv(
            context,
            'Arweave Proof',
            arweaveUrl == null ? '—' : 'View',
            onValueTap: arweaveUrl == null
                ? null
                : () => launchUrl(Uri.parse(arweaveUrl!), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {Widget? trailing, VoidCallback? onValueTap}) {
    final keyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withOpacityCompat(0.55),
      fontWeight: FontWeight.w600,
    );

    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withOpacityCompat(0.92),
      fontWeight: FontWeight.w800,
    );

    final valueWidget = onValueTap == null
        ? Text(v, style: valueStyle)
        : InkWell(
            onTap: onValueTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(v, style: valueStyle?.copyWith(color: AppColors.goldColor.withOpacityCompat(0.95))),
            ),
          );

    return Row(
      children: [
        Expanded(child: Text(k, style: keyStyle)),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            valueWidget,
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ],
    );
  }
}
