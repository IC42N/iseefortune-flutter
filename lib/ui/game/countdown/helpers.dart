import 'dart:ui';

class Band {
  const Band({required this.color, required this.intensity, required this.pulseMs});

  final Color color;
  final double intensity; // 0..1
  final int pulseMs;
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

Band bandForProgress01(double p) {
  p = _clamp01(p);

  const green = Color(0xFF17B454); // more muted// calmer green (less neon)
  const yellow = Color(0xFFFFD54A);
  const orange = Color(0xFFFF8A3D);
  const red = Color(0xFFFF3B3B);

  if (p <= 0.50) {
    return const Band(color: green, intensity: 0.15, pulseMs: 1800);
  }

  if (p <= 0.75) {
    final u = (p - 0.50) / 0.25;
    return Band(
      color: Color.lerp(green, yellow, u)!,
      intensity: 0.16 + (0.22 * u), // → tops out at ~0.38
      pulseMs: (1800 - (700 * u)).round(),
    );
  }

  if (p <= 0.85) {
    final u = (p - 0.75) / 0.10;
    return Band(
      color: Color.lerp(yellow, orange, u)!,
      intensity: 0.55 + (0.20 * u),
      pulseMs: (1100 - (350 * u)).round(),
    );
  }

  final u = (p - 0.85) / 0.15;
  return Band(
    color: Color.lerp(orange, red, u)!,
    intensity: 0.75 + (0.25 * u),
    pulseMs: (750 - (350 * u)).round(),
  );
}

String formatEtaSeconds(int seconds) {
  if (seconds <= 0) return '—';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '${m.toString()}:${s.toString().padLeft(2, '0')}';
}
