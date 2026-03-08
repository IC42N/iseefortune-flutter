import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

/// Small reusable glass card.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacityCompat(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
      ),
      child: child,
    );
  }
}
