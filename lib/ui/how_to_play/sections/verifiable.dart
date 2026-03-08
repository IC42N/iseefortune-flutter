import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:math' as math;

import 'package:iseefortune_flutter/ui/how_to_play/widgets/bullet_list.dart';
import 'package:iseefortune_flutter/ui/how_to_play/widgets/numbered_list.dart';
import 'package:iseefortune_flutter/ui/shared/link_button.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class VerifiableSection extends StatelessWidget {
  const VerifiableSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/svg/dividers/d2.svg',
          width: 140,
          height: 30,
          colorFilter: const ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'The winning number is derived entirely from public, immutable on-chain data on the Solana blockchain. '
            'Specifically, it is computed using the finalized blockhash and slot of the epoch—values that anyone can independently view on Solana Explorer.',
            style: TextStyle(
              color: Colors.white.withOpacityCompat(0.72),
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: Transform.rotate(
            angle: math.pi,
            child: SvgPicture.asset(
              'assets/svg/dividers/d2.svg',
              width: 140,
              height: 30,
              colorFilter: const ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
            ),
          ),
        ),

        const SizedBox(height: 32),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'To verify a result',
                  style: TextStyle(
                    color: Colors.white.withOpacityCompat(0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const NumberedList(
                items: [
                  ListItem(
                    leading: '1',
                    text: 'View the finalized blockhash and slot on Solana Explorer',
                    link: 'https://explorer.solana.com',
                  ),
                  ListItem(leading: '2', text: 'Run our open-source calculation script using those values'),
                  ListItem(leading: '3', text: 'Reproduce the winning number exactly'),
                ],
              ),

              const SizedBox(height: 18),

              Center(
                child: SvgPicture.asset(
                  'assets/svg/dividers/d3.svg',
                  width: 140,
                  height: 45,
                  colorFilter: const ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Fully transparent game mechanics',
                  style: TextStyle(
                    color: Colors.white.withOpacityCompat(0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'A complete resolution record is permanently uploaded to Arweave, containing:',
                style: TextStyle(
                  color: Colors.white.withOpacityCompat(0.72),
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),

              const SizedBox(height: 8),

              const BulletedList(
                items: [
                  'The blockhash and slot used in the calculation',
                  'The computed winning number',
                  'The full winners list',
                  'Tickets awarded and rollover data',
                  'Merkle proof data required for on-chain claims',
                ],
              ),

              const SizedBox(height: 18),

              Text(
                'Anyone can independently compare this record against Solana Explorer and reproduce the calculation without trusting us. '
                'If the data matches, the result is correct. If it doesn\'t, it\'s provably wrong.',
                style: TextStyle(
                  color: Colors.white.withOpacityCompat(0.72),
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: const [
                  Expanded(
                    child: LinkButton(
                      label: 'Read Specs',
                      url: 'https://github.com/IC42N/iseefortune-verifier/blob/main/SPEC.md',
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: LinkButton(label: 'Verify Result', url: 'https://verify.iseefortune.com'),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: LinkButton(label: 'View Source', url: 'https://github.com/IC42N'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: SvgPicture.asset(
                  'assets/svg/dividers/d3.svg',
                  width: 140,
                  height: 45,
                  colorFilter: const ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}
