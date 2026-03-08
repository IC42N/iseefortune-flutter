import 'package:flutter/material.dart';

@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  final Gradient background;
  final List<Color> dashboardBackground;

  const AppGradients({required this.background, required this.dashboardBackground});

  @override
  AppGradients copyWith({Gradient? background, List<Color>? dashboardBackground}) {
    return AppGradients(
      background: background ?? this.background,
      dashboardBackground: dashboardBackground ?? this.dashboardBackground,
    );
  }

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;

    // Safely lerp both gradient and dashboard colors
    final minLength = dashboardBackground.length < other.dashboardBackground.length
        ? dashboardBackground.length
        : other.dashboardBackground.length;

    return AppGradients(
      background: Gradient.lerp(background, other.background, t)!,
      dashboardBackground: List<Color>.generate(
        minLength,
        (i) => Color.lerp(dashboardBackground[i], other.dashboardBackground[i], t)!,
      ),
    );
  }
}
