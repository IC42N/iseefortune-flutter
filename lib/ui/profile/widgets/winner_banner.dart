// lib/ui/profile/widgets/winner_banner.dart
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/providers/claim/claim_provider.dart';
import 'package:iseefortune_flutter/ui/profile/helpers/helpers.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class WinBanner extends StatelessWidget {
  const WinBanner({
    super.key,
    required this.payoutLabel,
    required this.percentOfPotText,
    required this.onClaim,
    required this.claimState,
    this.isClaimedOverride,
    this.claimedAtOverride,
  });

  final String payoutLabel;
  final String percentOfPotText;
  final VoidCallback? onClaim;
  final ClaimState claimState;
  final bool? isClaimedOverride;
  final DateTime? claimedAtOverride;

  @override
  Widget build(BuildContext context) {
    final isBusy = claimState.isPreparing || claimState.isAwaitingSignature;

    final isClaimed = (isClaimedOverride ?? false) || claimState.isSuccess;

    // Button exists only when claimable (onClaim != null) OR we're mid-claim (busy).
    // Once claimed, it is NOT a button anymore.
    final showButton = !isClaimed && (onClaim != null || isBusy);

    final canPress = onClaim != null && !isBusy;
    final buttonLabel = buttonText(claimState);

    final claimedAt = claimedAtOverride ?? claimState.claimedAt;

    final showClaimedSubline =
        isClaimed && claimedAt != null && DateTime.now().difference(claimedAt).inDays >= 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F3A35).withOpacityCompat(0.92),
            const Color(0xFF12524A).withOpacityCompat(0.78),
            const Color(0xFF0A2421).withOpacityCompat(0.88),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacityCompat(0.08)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Congratulations - you won!',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white.withOpacityCompat(0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Payout: $payoutLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.goldColor.withOpacityCompat(0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '($percentOfPotText)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacityCompat(0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // RIGHT SIDE: either button (claim/processing) OR claimed text
          if (showButton)
            SizedBox(
              height: 26,
              child: FilledButton(
                onPressed: canPress ? onClaim : null,
                style:
                    FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacityCompat(0.08),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: Colors.white.withOpacityCompat(0.18), width: 1.2),
                      ),
                      elevation: 0,
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white.withOpacityCompat(0.04);
                        }
                        return Colors.white.withOpacityCompat(0.08);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white.withOpacityCompat(0.40);
                        }
                        return Colors.white;
                      }),
                      overlayColor: WidgetStateProperty.all(Colors.white.withOpacityCompat(0.12)),
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBusy) ...[
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      buttonLabel, // "Preparing…" / "Sign in wallet…" / "Claim"
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
            )
          else if (isClaimed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  claimedMainLine(claimState),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacityCompat(0.80),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showClaimedSubline) ...[
                  const SizedBox(height: 2),
                  Text(
                    claimedDateLine(claimedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: Colors.white.withOpacityCompat(0.55),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
