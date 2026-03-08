import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

/// Glassy sliding-pill tabs that match GamePagerTabs styling,
/// but driven by a TabController (for TabBarView).
class GameStyleTabs extends StatefulWidget {
  const GameStyleTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.height = 42,
    this.onTapIndex,
  });

  final TabController controller;
  final List<String> labels;
  final double height;

  /// Optional: if you want analytics or side-effects on tap.
  /// By default, we animate the controller to the index.
  final ValueChanged<int>? onTapIndex;

  @override
  State<GameStyleTabs> createState() => _GameStyleTabsState();
}

class _GameStyleTabsState extends State<GameStyleTabs> {
  double _t = 0.0;

  @override
  void initState() {
    super.initState();
    _t = widget.controller.index.toDouble();
    widget.controller.animation?.addListener(_onAnim);
  }

  @override
  void didUpdateWidget(covariant GameStyleTabs oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.animation?.removeListener(_onAnim);
      _t = widget.controller.index.toDouble();
      widget.controller.animation?.addListener(_onAnim);
    }
  }

  void _onAnim() {
    final v = widget.controller.animation?.value;
    if (v == null) return;
    if ((v - _t).abs() < 0.0001) return;
    setState(() => _t = v);
  }

  @override
  void dispose() {
    widget.controller.animation?.removeListener(_onAnim);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final count = labels.length;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final tabW = w / count;

        // sliding pill position (clamped)
        final pos = _t.clamp(0.0, (count - 1).toDouble()) * tabW;

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white.withOpacityCompat(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
              ),
              child: Stack(
                children: [
                  // Sliding pill
                  Positioned(
                    left: pos,
                    top: 0,
                    bottom: 0,
                    width: tabW,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withOpacityCompat(0.10),
                          border: Border.all(color: Colors.white.withOpacityCompat(0.12)),
                        ),
                      ),
                    ),
                  ),

                  // Labels / tap targets
                  Row(
                    children: List.generate(count, (i) {
                      final p = _proximity(_t, i.toDouble()); // 0..1
                      final selected = p > 0.6;

                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            widget.onTapIndex?.call(i);
                            widget.controller.animateTo(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                color: Color.lerp(
                                  Colors.white.withOpacityCompat(0.65),
                                  Colors.white.withOpacityCompat(0.95),
                                  p,
                                ),
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 1.0 when exactly on index, fades to 0.0 as you move away
  double _proximity(double t, double index) {
    final d = (t - index).abs();
    return (1.0 - d).clamp(0.0, 1.0);
  }
}
