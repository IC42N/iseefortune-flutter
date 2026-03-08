import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iseefortune_flutter/ui/shared/countdown_bet_cutoff.dart';
import 'package:iseefortune_flutter/ui/shared/coner_frame.dart';
import 'package:iseefortune_flutter/ui/shared/number_chip.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

enum PlayerBoxState { disconnected, connectedNoBet, connectedHasBet }

class PlayerBox extends StatelessWidget {
  const PlayerBox({
    super.key,
    required this.state,
    this.onConnect,
    this.onPlaceBet,
    this.onManageBet,
    this.predictionLabel,
    this.selections,
    this.amountLabel,
  });

  final PlayerBoxState state;

  final VoidCallback? onConnect;
  final VoidCallback? onPlaceBet;
  final VoidCallback? onManageBet;
  final String? predictionLabel;
  final List<int>? selections;
  final String? amountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picks = selections ?? const <int>[];

    final goldStyle = TextStyle(color: AppColors.goldColor, fontWeight: FontWeight.w700, fontSize: 10);

    late final String title;
    VoidCallback? onTap;

    switch (state) {
      case PlayerBoxState.disconnected:
        title = "Connect to play";
        onTap = onConnect;
        break;

      case PlayerBoxState.connectedNoBet:
        title = "Make your prediction";
        onTap = onPlaceBet;
        break;

      case PlayerBoxState.connectedHasBet:
        title = predictionLabel ?? "Your prediction is in";
        onTap = onManageBet;
        break;
    }

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Colors.white.withOpacityCompat(0.95),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Stack(
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildTitleWidget(
                            context,
                            title,
                            style: titleStyle,
                            enabled: state == PlayerBoxState.connectedHasBet,
                          ),
                          const SizedBox(height: 2),

                          if (state == PlayerBoxState.connectedHasBet && picks.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: [for (final n in picks) NumberChip(n, size: 30, intensity: 0.7)],
                            ),
                            const SizedBox(height: 6),
                          ],

                          _buildSubtitle(context),
                          const SizedBox(height: 4),
                          BetCutoffText(compact: true, style: goldStyle),
                        ].animate(interval: 50.ms).fadeIn(duration: 400.ms),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Positioned.fill(
              child: CornerFrame(asset: 'assets/svg/corners/c6.svg', size: 50, inset: 1, opacity: 0.75),
            ),
          ],
        ),
      ),
    );
  }

  /// For connectedHasBet, render digits in the title as colored spans.
  /// Example title: "You predicted: 1, 4, 7"
  Widget _buildTitleWidget(BuildContext context, String title, {TextStyle? style, required bool enabled}) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.titleMedium;

    // Only apply colored rendering for the "has bet" state.
    if (!enabled) {
      return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: effectiveStyle);
    }

    // Pull out digits (0-9) from the title, preserving separators.
    // This keeps "You predicted:" normal, and colors just the numbers.
    final spans = <InlineSpan>[];

    // If there are no digits, just render normally.
    final hasAnyDigit = RegExp(r'\d').hasMatch(title);
    if (!hasAnyDigit) {
      return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: effectiveStyle);
    }

    // Split into tokens of either digits or non-digits.
    final re = RegExp(r'\d+|[^\d]+');
    for (final m in re.allMatches(title)) {
      final chunk = m.group(0) ?? '';
      final asInt = int.tryParse(chunk);

      if (asInt != null && chunk.length == 1) {
        // Color single digit using your palette.
        spans.add(
          TextSpan(
            text: chunk,
            style: effectiveStyle?.copyWith(
              color: numberColor(asInt, intensity: 0.95),
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      } else {
        // Non-digits (and any multi-digit sequences) use default style.
        spans.add(TextSpan(text: chunk, style: effectiveStyle));
      }
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(height: 1.15, fontSize: 12, color: Colors.white.withOpacityCompat(0.70));

    switch (state) {
      case PlayerBoxState.connectedNoBet:
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                'Submit your predicitons before it closes!',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ],
          ),
        );

      case PlayerBoxState.connectedHasBet:
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(text: 'Amount: '),
              TextSpan(text: amountLabel ?? '—'),
            ],
          ),
        );

      case PlayerBoxState.disconnected:
        return Text(
          "Sign in with your wallet to place a prediction.",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: baseStyle,
        );
    }
  }
}
