// lib/utils/number_stats/number_colors.dart
import 'package:flutter/material.dart';

/// Mirrors the web app HUE_BY_NUMBER exactly.
// ignore: constant_identifier_names
const Map<int, double> HUE_BY_NUMBER = {
  0: 0,
  1: 195, // cyan
  2: 135, // green
  3: 55, // amber
  4: 20, // orange
  5: 330, // magenta
  6: 265, // purple
  7: 5, // red-orange
  8: 285, // violet
  9: 210, // blue
};

/// ---------------------------------------------------------------------------
/// EXISTING (keep): HSV-based helpers used elsewhere in the app
/// ---------------------------------------------------------------------------

/// Equivalent concept to `numberToCSSVars(num, intensity)`.
/// - hue comes from map
/// - intensity maps to HSV "value" and saturation
Color numberColor(
  int num, {
  double intensity = 0.9, // 0..1
  double saturation = 0.85,
}) {
  final hue = HUE_BY_NUMBER[num] ?? 0.0;

  // clamp just in case
  final v = intensity.clamp(0.0, 1.0);
  final s = saturation.clamp(0.0, 1.0);

  return HSVColor.fromAHSV(1.0, hue, s, v).toColor();
}

/// Optional: slightly dimmer version for borders / tracks.
Color numberColorDim(int num, {double intensity = 0.35}) {
  return numberColor(num, intensity: intensity, saturation: 0.75);
}

/// ---------------------------------------------------------------------------
/// NEW (add): HSL/HSLA helpers to match web CSS row tint EXACTLY
/// ---------------------------------------------------------------------------

/// Get hue from map (safe default).
double hueForNumber(int num) => HUE_BY_NUMBER[num] ?? 0.0;

/// Create an HSLA color (matches CSS hsla()).
///
/// s and l are 0..1, a is 0..1, hue in degrees.
Color hsla(double hue, double s, double l, double a) {
  return HSLColor.fromAHSL(a.clamp(0.0, 1.0), hue % 360.0, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0)).toColor();
}

/// Matches the web chip's 2-stop radial gradient:
/// radial-gradient(... hsla(hue,95%,70%, intensity*0.45), hsla(hue,90%,45%, intensity*0.22))
List<Color> chipRadialStops(int num, double intensity) {
  final hue = hueForNumber(num);
  final a1 = (intensity * 0.45).clamp(0.0, 1.0);
  final a2 = (intensity * 0.22).clamp(0.0, 1.0);

  return [hsla(hue, 0.95, 0.70, a1), hsla(hue, 0.90, 0.45, a2)];
}

/// Border: 1px solid hsla(hue, 90%, 70%, 0.22)
Color chipBorder(int num) {
  final hue = hueForNumber(num);
  return hsla(hue, 0.90, 0.70, 0.22);
}

/// Outer glow: 0 0 34px hsla(hue, 95%, 60%, 0.25)
Color chipGlow(int num) {
  final hue = hueForNumber(num);
  return hsla(hue, 0.95, 0.60, 0.25);
}

/// Palette for the PredictionRow background/rail/pk that mirrors the web CSS:
/// - ::after tint:  hsla(hue, 95%, 55%, 0.22 / 0.04 / 0.10)
/// - ::before rail: hsla(hue, 95%, 70%, 0.85) -> hsla(hue, 95%, 55%, 0.35)
/// - pk color:       hsla(hue, 95%, 70%, 0.85)
/// - glow:           hsla(hue, 95%, 60%, 0.22)
class RowHuePalette {
  RowHuePalette(this.hue);

  final double hue;

  Color get tintStrong => hsla(hue, 0.95, 0.55, 0.22);
  Color get tintSoft => hsla(hue, 0.95, 0.55, 0.04);
  Color get tintEnd => hsla(hue, 0.95, 0.55, 0.10);

  Color get railTop => hsla(hue, 0.95, 0.70, 0.85);
  Color get railBottom => hsla(hue, 0.95, 0.55, 0.35);

  Color get pkColor => hsla(hue, 0.95, 0.70, 0.95);

  Color get railGlow => hsla(hue, 0.95, 0.60, 0.22);
}
