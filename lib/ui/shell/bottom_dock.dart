import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/ball_icon.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'nav_item.dart';

class BottomDock extends StatelessWidget {
  const BottomDock({super.key, required this.index, required this.onTab});

  final int index;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bottom navigation bar (glassy + background)
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.only(bottom: bottomPad),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F1A).withOpacityCompat(0.85),
                border: Border(
                  top: BorderSide(color: Color.fromARGB(255, 22, 30, 50).withOpacityCompat(0.85)),
                ),
              ),
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    Expanded(
                      child: NavItem(
                        selected: index == 0,
                        icon: svgBall(size: 20, color: Colors.white70),
                        activeIcon: svgBall(size: 22, color: AppColors.goldColor),
                        label: 'Game',
                        onTap: () => onTab(0),
                      ),
                    ),

                    Expanded(
                      child: NavItem(
                        selected: index == 1,
                        icon: const Icon(Icons.history_outlined, size: 20),
                        activeIcon: Icon(Icons.history, size: 22, color: AppColors.goldColor),
                        label: 'History',
                        onTap: () => onTab(1),
                      ),
                    ),

                    Expanded(
                      child: NavItem(
                        selected: index == 2,
                        icon: const Icon(Icons.person_2_outlined, size: 20),
                        activeIcon: Icon(Icons.person_2, size: 22, color: AppColors.goldColor),
                        label: 'My Profile',
                        onTap: () => onTab(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
