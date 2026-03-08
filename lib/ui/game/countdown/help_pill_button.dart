import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class HelpPillButton extends StatelessWidget {
  const HelpPillButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(7, 5, 14, 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacityCompat(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacityCompat(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacityCompat(0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.goldColor.withOpacityCompat(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.goldColor.withOpacityCompat(0.20)),
                ),
                child: Text(
                  '?',
                  style: TextStyle(
                    color: AppColors.goldColor.withOpacityCompat(0.95),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'How to play',
                style: TextStyle(
                  color: Colors.white.withOpacityCompat(0.82),
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
