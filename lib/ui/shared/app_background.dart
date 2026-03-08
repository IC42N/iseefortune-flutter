import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/star_warp.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _GradientLayer(),

        // Layer 1: fixed star warp
        const IgnorePointer(child: Opacity(opacity: 0.55, child: StarWarp(baseSpeed: 4, centerBiasY: 0))),

        // Layer 2: your app
        child,
      ],
    );
  }
}

class _GradientLayer extends StatelessWidget {
  const _GradientLayer();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF05060A), Color(0xFF070A12), Color(0xFF0B0F1A)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
