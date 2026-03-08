import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class GamePagerTabs extends StatefulWidget {
  const GamePagerTabs({super.key, required this.controller, required this.labels, required this.onTapIndex});

  final PageController controller;
  final List<String> labels;
  final ValueChanged<int> onTapIndex;

  @override
  State<GamePagerTabs> createState() => _GamePagerTabsState();
}

class _GamePagerTabsState extends State<GamePagerTabs> {
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.controller.initialPage.toDouble();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant GamePagerTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      _page = widget.controller.initialPage.toDouble();
      widget.controller.addListener(_onScroll);
    }
  }

  void _onScroll() {
    final p = widget.controller.page;
    if (p == null) return;
    if ((p - _page).abs() < 0.0001) return;
    setState(() => _page = p);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
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

        // Clamp to prevent overscroll glow affecting the pill position
        final pos = _page.clamp(0.0, (count - 1).toDouble()) * tabW;

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 42,
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
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacityCompat(0.10),
                          border: Border.all(color: Colors.white.withOpacityCompat(0.12)),
                        ),
                      ),
                    ),
                  ),

                  // Labels (tap targets)
                  Row(
                    children: List.generate(count, (i) {
                      final t = _proximity(_page, i.toDouble()); // 0..1
                      final selected = t > 0.6;

                      return Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => widget.onTapIndex(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.3,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                color: Color.lerp(
                                  Colors.white.withOpacityCompat(0.65),
                                  Colors.white.withOpacityCompat(0.95),
                                  t,
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

  // returns 1.0 when exactly on index, fades to 0.0 as you move away
  double _proximity(double page, double index) {
    final d = (page - index).abs();
    return (1.0 - d).clamp(0.0, 1.0);
  }
}
