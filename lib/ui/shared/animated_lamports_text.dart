import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

class _BigIntTween extends Tween<BigInt> {
  _BigIntTween({required BigInt begin, required BigInt end}) : super(begin: begin, end: end);

  @override
  BigInt lerp(double t) {
    final b = begin ?? BigInt.zero;
    final e = end ?? BigInt.zero;
    if (t <= 0) return b;
    if (t >= 1) return e;

    final diff = e - b;
    const scale = 1000000; // fixed-point
    final k = (t * scale).round().clamp(0, scale);
    return b + (diff * BigInt.from(k)) ~/ BigInt.from(scale);
  }
}

/// Casino-style count up/down for lamports -> SOL text, but:
/// - coalesces rapid updates
/// - skips animation for tiny deltas
class AnimatedLamportsSolText extends StatefulWidget {
  const AnimatedLamportsSolText({
    super.key,
    required this.lamports,
    required this.textStyle,
    this.duration = const Duration(milliseconds: 850),
    this.curve = Curves.easeOutCubic,
    this.placeholder = '—',

    /// Minimum time between starting animations.
    this.minAnimateGap = const Duration(milliseconds: 140),

    /// Only animate if abs(deltaLamports) >= this threshold (in lamports).
    /// Default: 0.001 SOL = 1,000,000 lamports.
    this.minDeltaLamportsToAnimate = 1000000,
  });

  final BigInt? lamports;
  final TextStyle textStyle;

  final Duration duration;
  final Curve curve;
  final String placeholder;

  final Duration minAnimateGap;

  /// Lamports threshold (int so it can be const-friendly).
  final int minDeltaLamportsToAnimate;

  @override
  State<AnimatedLamportsSolText> createState() => _AnimatedLamportsSolTextState();
}

class _AnimatedLamportsSolTextState extends State<AnimatedLamportsSolText> {
  BigInt? _shown; // target we are animating to / displaying
  BigInt? _pending; // newest value we want to end at
  BigInt? _from; // start value for the next animation

  DateTime _lastAnimStart = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _flushTimer;

  BigInt get _minDelta => BigInt.from(widget.minDeltaLamportsToAnimate);

  @override
  void initState() {
    super.initState();
    _shown = widget.lamports;
    _from = widget.lamports;
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedLamportsSolText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final next = widget.lamports;

    if (next == null) {
      _flushTimer?.cancel();
      setState(() {
        _pending = null;
        _shown = null;
        _from = null;
      });
      return;
    }

    if (_shown == null) {
      _flushTimer?.cancel();
      setState(() {
        _shown = next;
        _from = next;
        _pending = null;
      });
      return;
    }

    if (next == _shown) return;

    _pending = next;

    final now = DateTime.now();
    final since = now.difference(_lastAnimStart);

    if (since >= widget.minAnimateGap) {
      _flushPending(now);
    } else {
      _flushTimer?.cancel();
      final wait = widget.minAnimateGap - since;
      _flushTimer = Timer(wait, () => _flushPending(DateTime.now()));
    }
  }

  void _flushPending(DateTime now) {
    final next = _pending;
    final current = _shown;
    if (next == null || current == null) return;

    _flushTimer?.cancel();
    _flushTimer = null;

    final delta = (next - current).abs();

    if (delta < _minDelta) {
      setState(() {
        _from = next;
        _shown = next;
        _pending = null;
      });
      return;
    }

    setState(() {
      _from = current;
      _shown = next;
      _pending = null;
      _lastAnimStart = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final end = _shown;

    if (end == null) {
      return Text(widget.placeholder, style: widget.textStyle, textAlign: TextAlign.center);
    }

    final begin = _from ?? end;

    return TweenAnimationBuilder<BigInt>(
      key: ValueKey<BigInt>(end), // new tween per target
      tween: _BigIntTween(begin: begin, end: end),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, v, _) {
        return Text('${lamportsToSolText(v)} SOL', style: widget.textStyle, textAlign: TextAlign.center);
      },
    );
  }
}
