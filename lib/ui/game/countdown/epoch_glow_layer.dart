import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class EpochGlowLayer extends StatefulWidget {
  const EpochGlowLayer({
    super.key,
    required this.size,
    required this.color,
    required this.pulseMs,
    required this.intensity, // 0..1
    this.startDelay = const Duration(milliseconds: 280),
  });

  final double size;
  final Color color;
  final double intensity;
  final int pulseMs;
  final Duration startDelay;

  @override
  State<EpochGlowLayer> createState() => _EpochGlowLayerState();
}

class _EpochGlowLayerState extends State<EpochGlowLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _started = false;
  int _lastPulseMs = 0;
  bool _updateQueued = false;

  @override
  void initState() {
    super.initState();
    _lastPulseMs = widget.pulseMs;

    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _lastPulseMs),
    )..repeat(reverse: true);

    // start after delay (no setState spam)
    Future.delayed(widget.startDelay, () {
      if (!mounted) return;
      _started = true;
      _pulse.repeat(reverse: true);
      // no need to call setState; AnimatedBuilder listens to _pulse
    });
  }

  @override
  void didUpdateWidget(covariant EpochGlowLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If you want pulse speed to react to intensity, do it here (NOT in build).
    // Keep it simple for now: no duration changes unless you want them.
    // Only react if pulse speed meaningfully changes
    if ((widget.pulseMs - _lastPulseMs).abs() <= 40) return;

    _lastPulseMs = widget.pulseMs;

    if (_updateQueued) return;
    _updateQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueued = false;
      if (!mounted) return;

      _pulse.duration = Duration(milliseconds: _lastPulseMs);

      // Restart smoothly
      _pulse
        ..reset()
        ..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final pulse = _started ? _pulse.value : 0.0;

        final pulseStrength = widget.intensity;
        final pulseFactor = 0.60 + (0.40 * pulse);

        final glowOpacity = _started ? (0.10 + 0.55 * pulseStrength) * pulseFactor : 0.18;
        final blur = _started ? (18.0 + (34.0 * pulseStrength)) : 22.0;
        final spread = _started ? (1.0 + (7.0 * pulseStrength)) : 2.0;
        final scale = _started ? 1.0 + (0.006 + 0.014 * pulseStrength) * pulse : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size * 0.80,
            height: widget.size * 0.80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacityCompat(glowOpacity),
                  blurRadius: blur,
                  spreadRadius: spread,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
