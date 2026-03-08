import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/glass_card.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class RuleCard extends StatelessWidget {
  const RuleCard({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacityCompat(0.92),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacityCompat(0.65),
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
