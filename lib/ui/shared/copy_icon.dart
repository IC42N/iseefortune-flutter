import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class CopyIcon extends StatelessWidget {
  const CopyIcon({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.copy_rounded, size: 16, color: Colors.white.withOpacityCompat(0.65)),
      ),
    );
  }
}
