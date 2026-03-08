import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class OverviewSection extends StatelessWidget {
  const OverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SvgPicture.asset(
          'assets/svg/dividers/d1.svg',
          width: 140,
          height: 20,
          colorFilter: const ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: EdgeInsetsGeometry.fromLTRB(13, 0, 13, 0),
          child: Text(
            'At the end of each Solana epoch, a winning number (0~9) is computed from the final blockhash. Use your intuition, pick a number, and set your conviction amount. True randomness will decide your fate. If your number is chosen, the pot is split among winners proportional to the amount you contribute.',
            style: TextStyle(
              color: Colors.white.withOpacityCompat(0.92),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 18),

        Center(
          child: Transform.rotate(
            angle: math.pi,
            child: SvgPicture.asset(
              'assets/svg/dividers/d1.svg',
              width: 140,
              height: 20,
              colorFilter: const ColorFilter.mode(AppColors.goldColor, BlendMode.srcIn),
            ),
          ),
        ),

        const SizedBox(height: 22),

        Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'What makes this game different?',
                  style: TextStyle(color: AppColors.goldColor, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withOpacityCompat(0.95),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(
                      text:
                          'Outcomes are fully deterministic and reproducible by anyone from Solana finalized data. '
                          'There is no private random generator, no oracle. No "Trust me bro". ',
                    ),
                    TextSpan(
                      text: 'Read full documentation.',
                      style: TextStyle(color: AppColors.goldColor, fontWeight: FontWeight.w700),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          final uri = Uri.parse('https://docs.iseefortune.com');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
      ],
    );
  }
}
