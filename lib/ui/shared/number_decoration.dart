import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

BoxDecoration numberBarDecoration(int number, {required bool isZero, required double intensity}) {
  // Bars should be punchy but not neon.
  // Keep opacity high; mute via saturation/value instead.
  final top = numberColor(number, intensity: isZero ? 0.55 : 0.85, saturation: 0.75).withOpacityCompat(0.95);

  final bottom = numberColor(
    number,
    intensity: isZero ? 0.10 : 0.50,
    saturation: 0.70,
  ).withOpacityCompat(0.88);

  return BoxDecoration(
    borderRadius: BorderRadius.circular(999),
    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
    // Very light outline so it doesn't scream
    border: Border.all(color: Colors.white.withOpacityCompat(0.10), width: 1),
  );
}
