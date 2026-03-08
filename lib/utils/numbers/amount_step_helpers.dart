double clamp(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

double roundToStep(double v) => (v * 100).round() / 100.0;

int divisionsForStep(double min, double max, double step) {
  final span = max - min;
  if (span <= 0) return 1;
  final div = (span / step).round();
  return div < 1 ? 1 : div;
}
