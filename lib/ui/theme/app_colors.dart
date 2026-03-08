import 'package:flutter/material.dart';

class AppColors {
  static const Color goldColor = Color(0xFFBFB47B);

  static final Color darkBlue = Color.fromARGB(255, 14, 22, 37);

  // Neutral tones (muted whites & blacks)
  static const Color white = Color.fromARGB(255, 224, 224, 224); // muted white
  static const Color black = Color.fromARGB(255, 68, 68, 68); // muted black
  static const Color greyLight = Color.fromARGB(255, 200, 200, 200);
  static const Color grey = Color.fromARGB(255, 140, 140, 140);
  static const Color greyDark = Color.fromARGB(255, 90, 90, 90);

  // Muted primaries
  static const Color green = Color.fromARGB(255, 99, 156, 99); // muted green
  static const Color blue = Color.fromARGB(255, 80, 130, 170); // muted blue
  static const Color purple = Color.fromARGB(255, 120, 100, 150); // muted purple
  static const Color red = Color.fromARGB(255, 160, 90, 90); // muted red
  static const Color orange = Color.fromARGB(255, 190, 130, 80); // muted orange
  static const Color yellow = Color.fromARGB(255, 190, 190, 100); // muted yellow

  // Muted brand-specific
  static const Color skrPrimary = Color.fromARGB(255, 60, 150, 120); // muted teal/green
  static const Color skrSecondary = Color.fromARGB(255, 70, 110, 160); // muted blue
  static const Color skrAccent = Color.fromARGB(255, 130, 90, 150); // muted purple
}

extension ColorAlpha on Color {
  /// Apply alpha using a 0.0–1.0 double, converts internally to 0–255
  Color withOpacityCompat(double opacity) {
    final alphaValue = (255 * opacity).clamp(0, 255).toInt();
    return withAlpha(alphaValue);
  }
}
