import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class DismissButton extends StatelessWidget {
  const DismissButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).pop(),
        child: Ink(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withOpacityCompat(0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacityCompat(0.45)),
          ),
          child: const Icon(Icons.close, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
