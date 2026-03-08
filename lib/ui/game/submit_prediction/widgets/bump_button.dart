import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class BumpButton extends StatelessWidget {
  const BumpButton({super.key, required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.white.withOpacityCompat(0.92) : Colors.white.withOpacityCompat(0.28);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacityCompat(enabled ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacityCompat(enabled ? 0.12 : 0.07)),
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }
}
