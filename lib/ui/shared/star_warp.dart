// lib/ui/shared/star_warp.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class StarWarp extends StatefulWidget {
  const StarWarp({
    super.key,

    // Let these be "minimums"; we’ll scale them by screen area.
    this.warpCount = 70,
    this.bgCount = 1600,

    // Faster by default.
    this.baseSpeed = 22.0,

    // Center bias (negative = slightly up, positive = lower)
    this.centerBiasY = -0.10,

    // Streak multiplier
    this.streak = 2.8,
    this.opacity = 0.75,

    // Auto density scaling
    this.autoDensity = true,

    // ------------------------------------------------------------
    // ✅ ONE SWITCH: spawn smoothing (fade-in + stagger + calmer respawn)
    // ------------------------------------------------------------
    this.spawnSmoothing = true,

    // Only used when spawnSmoothing == true
    this.fadeInSeconds = 0.35,
    this.respawnStaggerMax = 0.18,
    this.calmRespawnZMax = 1.0,
  });

  final int warpCount;
  final int bgCount;
  final double baseSpeed;
  final double centerBiasY;
  final double streak;
  final double opacity;
  final bool autoDensity;

  /// Master toggle: when false, no cooldown/age/fade-in/stagger.
  final bool spawnSmoothing;

  /// Fade-in duration (seconds) for newly respawned warp stars.
  final double fadeInSeconds;

  /// Max stagger delay (seconds) after respawn.
  final double respawnStaggerMax;

  /// Respawn z randomness max (when smoothing on). Lower = calmer, less “blast”.
  final double calmRespawnZMax;

  @override
  State<StarWarp> createState() => _StarWarpState();
}

class _StarWarpState extends State<StarWarp> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final _rng = Random();
  Size _size = Size.zero;

  int _bgInitedCount = 0;
  int _warpInitedCount = 0;

  final List<_BgStar> _bg = [];
  final List<_WarpStar> _warp = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final rawDt = _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    final dt = rawDt.clamp(0.0, 0.033); // prevent hitch jumps
    _last = now;

    if (_size == Size.zero) {
      setState(() {});
      return;
    }

    _ensureCounts();

    final cx = _size.width * 0.5;
    final cy = _size.height * (0.5 + widget.centerBiasY);

    // BG twinkle
    for (final s in _bg) {
      s.tw += dt * s.twSpeed;
    }

    // Warp motion
    final speed = widget.baseSpeed;

    const zMax = 6.0;
    const zAccel = 2.2;
    const zMin = 0.6;
    const margin = 90.0;

    for (final w in _warp) {
      // ------------------------------------------------------------
      // Optional: cooldown to stagger respawns
      // ------------------------------------------------------------
      if (widget.spawnSmoothing && w.cooldown > 0.0) {
        w.cooldown -= dt;
        w.px = w.x;
        w.py = w.y;
        continue;
      }

      // Optional: age for fade-in
      if (widget.spawnSmoothing) {
        w.age += dt;
      } else {
        // keep it effectively "fully on"
        w.age = 999.0;
        w.cooldown = 0.0;
      }

      w.px = w.x;
      w.py = w.y;

      // z accel
      final t = (w.z / zMax).clamp(0.0, 1.0);
      final accel = zAccel * (0.35 + 0.65 * t * t);
      w.z = (w.z + dt * accel).clamp(zMin, zMax);

      final zCurve = 0.55 + 0.45 * (w.z / zMax);
      final step = speed * w.z * zCurve * dt;

      w.x += w.vx * step;
      w.y += w.vy * step;

      if (w.x < -margin || w.x > _size.width + margin || w.y < -margin || w.y > _size.height + margin) {
        _spawnWarpNearCenter(w, cx, cy);
      }
    }

    setState(() {});
  }

  void _spawnWarpNearCenter(_WarpStar w, double cx, double cy) {
    final angle = _rng.nextDouble() * pi * 2;
    final dirX = cos(angle);
    final dirY = sin(angle);

    // Soft spawn disk (scales with screen size)
    final maxSpawnRadius = min(_size.width, _size.height) * 0.12; // ~8% of screen
    final u = _rng.nextDouble();

    // sqrt distribution = denser near center, but wide
    final startR = sqrt(u) * maxSpawnRadius;

    w.x = cx + dirX * startR;
    w.y = cy + dirY * startR;
    w.px = w.x;
    w.py = w.y;

    final jitter = 0.10;
    w.vx = dirX + (_rng.nextDouble() - 0.5) * jitter;
    w.vy = dirY + (_rng.nextDouble() - 0.5) * jitter;

    // z/r
    if (widget.spawnSmoothing) {
      // calmer respawn to avoid “blast”
      w.z = 0.6 + _rng.nextDouble() * widget.calmRespawnZMax; // e.g. max 1.0
    } else {
      // classic feel: allow wider starting z
      w.z = 0.6 + _rng.nextDouble() * 2.2;
    }

    w.r = 0.6 + _rng.nextDouble() * 1.6;

    // blend + stagger
    if (widget.spawnSmoothing) {
      w.age = 0.0;
      w.cooldown = _rng.nextDouble() * widget.respawnStaggerMax; // stagger respawns
    } else {
      w.age = 999.0;
      w.cooldown = 0.0;
    }
  }

  void _spawnWarpAnywhere(_WarpStar w, double cx, double cy) {
    // Fill the screen at boot / when density increases
    w.x = _rng.nextDouble() * _size.width;
    w.y = _rng.nextDouble() * _size.height;
    w.px = w.x;
    w.py = w.y;

    // Direction away from center
    var dx = w.x - cx;
    var dy = w.y - cy;
    final len = sqrt(dx * dx + dy * dy).clamp(0.0001, 1e9);
    dx /= len;
    dy /= len;

    final jitter = 0.08;
    w.vx = dx + (_rng.nextDouble() - 0.5) * jitter;
    w.vy = dy + (_rng.nextDouble() - 0.5) * jitter;

    // Randomize z so some are already fast/bright
    w.z = 0.9 + _rng.nextDouble() * 4.5;
    w.r = 0.5 + _rng.nextDouble() * 1.4;

    // initial fill should never “pop”
    w.age = 999.0;
    w.cooldown = 0.0;
  }

  int _scaledCount(int base, Size s, {int min = 0, int max = 5000}) {
    if (!widget.autoDensity) return base;

    // Reference ~ iPhone 13 Pro-ish area
    const refArea = 390.0 * 844.0;
    final area = (s.width * s.height).clamp(1.0, 1e9);

    final scale = sqrt(area / refArea);
    final v = (base * scale).round();
    return v.clamp(min == 0 ? base : min, max);
  }

  void _ensureCounts() {
    if (_size == Size.zero) return;

    final targetBg = _scaledCount(widget.bgCount, _size, max: 4000);
    final targetWarp = _scaledCount(widget.warpCount, _size, max: 1200);

    while (_bg.length < targetBg) {
      _bg.add(_BgStar());
    }
    while (_warp.length < targetWarp) {
      _warp.add(_WarpStar());
    }

    if (_bg.length > targetBg) {
      _bg.removeRange(targetBg, _bg.length);
      _bgInitedCount = _bgInitedCount.clamp(0, _bg.length);
    }
    if (_warp.length > targetWarp) {
      _warp.removeRange(targetWarp, _warp.length);
      _warpInitedCount = _warpInitedCount.clamp(0, _warp.length);
    }

    // Init newly-added stars
    final cx = _size.width * 0.5;
    final cy = _size.height * (0.5 + widget.centerBiasY);

    for (var i = _bgInitedCount; i < _bg.length; i++) {
      final s = _bg[i];
      s.x = _rng.nextDouble() * _size.width;
      s.y = _rng.nextDouble() * _size.height;
      s.r = 0.4 + _rng.nextDouble() * 1.2;
      s.tw = _rng.nextDouble() * pi * 2;
      s.twSpeed = 0.4 + _rng.nextDouble() * 1.1;
      s.a = 0.08 + _rng.nextDouble() * 0.35;
    }
    _bgInitedCount = _bg.length;

    for (var i = _warpInitedCount; i < _warp.length; i++) {
      _spawnWarpAnywhere(_warp[i], cx, cy);
    }
    _warpInitedCount = _warp.length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return CustomPaint(
          painter: _StarWarpPainter(
            bg: _bg,
            warp: _warp,
            opacity: widget.opacity,
            streak: widget.streak,
            spawnSmoothing: widget.spawnSmoothing,
            fadeInSeconds: widget.fadeInSeconds,
          ),
        );
      },
    );
  }
}

class _StarWarpPainter extends CustomPainter {
  _StarWarpPainter({
    required this.bg,
    required this.warp,
    required this.opacity,
    required this.streak,
    required this.spawnSmoothing,
    required this.fadeInSeconds,
  });

  final List<_BgStar> bg;
  final List<_WarpStar> warp;
  final double opacity;
  final double streak;

  final bool spawnSmoothing;
  final double fadeInSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    // BG dots
    final pDot = Paint()..style = PaintingStyle.fill;
    for (final s in bg) {
      final tw = 0.75 + 0.25 * sin(s.tw);
      pDot.color = Colors.white.withOpacityCompat((s.a * tw * opacity).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(s.x, s.y), s.r, pDot);
    }

    // Warp streaks
    final pLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final w in warp) {
      final fadeIn = spawnSmoothing ? (w.age / fadeInSeconds).clamp(0.0, 1.0) : 1.0;

      final zNorm = (w.z / 6.0).clamp(0.0, 1.0);

      // Stronger presence, same dynamics
      final a =
          (opacity *
                  (0.28 + zNorm * 0.92) * // ⬆️ higher base + slightly stronger ramp
                  fadeIn)
              .clamp(0.0, 1.0);
      if (a <= 0.001) continue;

      pLine.color = Colors.white.withOpacityCompat(a);
      pLine.strokeWidth = (0.7 + (w.z / 6.0) * 1.8) * (w.r / 2.0);

      final dx = (w.x - w.px) * streak;
      final dy = (w.y - w.py) * streak;

      canvas.drawLine(Offset(w.x - dx, w.y - dy), Offset(w.x, w.y), pLine);
    }
  }

  @override
  bool shouldRepaint(covariant _StarWarpPainter oldDelegate) => true;
}

class _BgStar {
  double x = 0, y = 0;
  double r = 1;
  double a = 0.2;
  double tw = 0;
  double twSpeed = 1;
}

class _WarpStar {
  double x = 0, y = 0;
  double px = 0, py = 0;
  double vx = 0, vy = 0;
  double z = 1.0;
  double r = 1.0;

  // ✅ used for smoothing (safe even when disabled)
  double age = 999.0;
  double cooldown = 0.0;
}
