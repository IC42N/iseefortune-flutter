import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class Callout extends StatelessWidget {
  const Callout({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.goldColor.withOpacityCompat(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldColor.withOpacityCompat(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldColor.withOpacityCompat(0.15),
            ),
            child: Icon(Icons.lightbulb_rounded, size: 16, color: AppColors.goldColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                color: Colors.white.withOpacityCompat(0.78),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
