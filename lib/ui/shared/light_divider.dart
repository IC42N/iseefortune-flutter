import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class LightDivider extends StatelessWidget {
  const LightDivider({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.opacity = 0.10,
    this.inset = 0,
  });

  /// Vertical spacing around the divider
  final EdgeInsets padding;

  /// Opacity of the center line (0.05–0.12 recommended)
  final double opacity;

  /// Horizontal inset (useful inside cards / modals)
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding.add(EdgeInsets.symmetric(horizontal: inset)),
      child: Container(
        height: 1,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.white.withOpacityCompat(opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
