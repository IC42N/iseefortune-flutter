import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/how_to_play/widgets/rule_card.dart';
import 'package:iseefortune_flutter/ui/shared/glass_card.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class GameRulesSection extends StatelessWidget {
  const GameRulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const RuleCard(title: 'Predictions', body: 'You can place one prediction per tier per wallet.'),
        const SizedBox(height: 7),

        const RuleCard(
          title: 'Chance of winning',
          body: 'With a single prediction you always have a 1 in 8 chance of selecting the winning number.',
        ),
        const SizedBox(height: 7),

        const RuleCard(
          title: 'Tiers',
          body:
              'The game currently runs in Tier 1. New tiers will open as the game grows, with higher bet ranges for higher stakes.',
        ),
        const SizedBox(height: 7),

        const RuleCard(
          title: 'Taker fee',
          body: 'A default taker fee is applied to each pot. Net pot is the gross pot minus the taker fee.',
        ),
        const SizedBox(height: 7),

        const RuleCard(
          title: 'Rollover numbers',
          body:
              'There are two rollover numbers: 0 and the last winning number. If the winning number happens to be a rollover number, the game rolls over into the next epoch.\n\n'
              'On this event, nobody wins, nobody loses, all predictions and the entire pot is carried over to the next epoch. Predictions can be changed and conviction can be increased.\n\n'
              'As a bonus on this rare event, the taker fee drops by 1%.',
        ),
        const SizedBox(height: 10),
        const RuleCard(
          title: 'How payouts work',
          body:
              'All predictions contribute to a shared pot. A protocol fee may be taken, and the remaining pot is split among winning players.',
        ),
        const SizedBox(height: 10),
        const RuleCard(
          title: 'Your share',
          body:
              'If your number wins, your payout is proportional to your conviction relative to the other winners on that number.',
        ),
        const SizedBox(height: 10),
        const RuleCard(
          title: 'Claiming',
          body:
              'After the epoch resolves, winnings are claimed from your Profile. Claims are verified on-chain using proof data from the resolution.',
        ),
        const SizedBox(height: 10),

        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Tickets',
                style: TextStyle(
                  color: Colors.white.withOpacityCompat(0.92),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Change tickets are auto awarded to a percentage of players who miss the winning number as a consolation prize. '
                'As all selected prediction number are by default final, a change ticket lets you over ride this and change your prediction before the '
                'cutoff time for maximum exposure. It is very powerful as switching your prediction to a number with less players can greatly increase pot share if it wins.\n\n'
                'Note: This does not increase the chance of winning, it only increases the possible payout if that number wins.',
                style: TextStyle(
                  color: Colors.white.withOpacityCompat(0.65),
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
