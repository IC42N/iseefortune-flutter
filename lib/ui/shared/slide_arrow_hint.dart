import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class SlideHint extends StatefulWidget {
  const SlideHint({super.key});

  @override
  State<SlideHint> createState() => _SlideHintState();
}

class _SlideHintState extends State<SlideHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _dx; // nudge right
  late final Animation<double> _pulse; // opacity pulse

  @override
  void initState() {
    super.initState();

    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: false);

    // Smooth “nudge right then reset”
    _dx = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 45,
      ),
    ]).animate(_c);

    // Gentle pulse
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.28, end: 0.55).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.28).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(_dx.value, 0),
              child: Opacity(
                opacity: _pulse.value,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: AppColors.goldColor,
                  shadows: [Shadow(color: AppColors.goldColor.withOpacityCompat(0.35), blurRadius: 10)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
