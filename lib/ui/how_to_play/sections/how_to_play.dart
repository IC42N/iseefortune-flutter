// -----------------------------------------------------------------------------
// Tab 1: How to Play
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/how_to_play/widgets/callout.dart';
import 'package:iseefortune_flutter/ui/shared/glass_card.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class HowToPlaySection extends StatelessWidget {
  const HowToPlaySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _StepCard(
          num: '1',
          title: 'Connect your wallet',
          body: 'Connect to place a prediction and receive payouts.',
        ),
        SizedBox(height: 6),
        _StepCard(
          num: '2',
          title: 'Predict the next number',
          body:
              'Use your intuition and determine what number will come next. Place your prediction before the epoch ends.',
        ),
        SizedBox(height: 6),
        _StepCard(
          num: '3',
          title: 'Wait for the epoch to resolve',
          body: 'When the epoch ends, the winning number is computed and your fate will be decided.',
        ),
        SizedBox(height: 6),
        _StepCard(
          num: '4',
          title: 'Collect winnings',
          body:
              'If your intuitions was correct, you will receive the portion relative to your conviction. Payouts are claimed in your profile.',
        ),
        SizedBox(height: 12),
        Callout(body: 'Fewer players on a number usually means a bigger share if it wins.'),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.num, required this.title, required this.body});
  final String num;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepNum(num: num),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacityCompat(0.92),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: Colors.white.withOpacityCompat(0.65),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepNum extends StatelessWidget {
  const _StepNum({required this.num});
  final String num;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacityCompat(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
      ),
      child: Text(
        num,
        style: TextStyle(
          color: Colors.white.withOpacityCompat(0.92),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}
