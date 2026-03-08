import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class PagerDots extends StatelessWidget {
  const PagerDots({super.key, required this.controller, required this.count});

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients ? (controller.page ?? controller.initialPage.toDouble()) : 0.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final dist = (page - i).abs().clamp(0.0, 1.0);
            final t = 1.0 - dist; // 1 = active, 0 = far

            final width = lerpDouble(8, 22, t)!;
            final opacity = lerpDouble(0.25, 0.90, t)!;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: width,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withOpacityCompat(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
