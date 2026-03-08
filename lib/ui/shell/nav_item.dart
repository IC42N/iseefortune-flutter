import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.activeColor = AppColors.goldColor,
    this.inactiveColor = Colors.white70,
  });

  final bool selected;
  final Widget icon;
  final Widget activeIcon;
  final String label;
  final VoidCallback onTap;

  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = selected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(color: color),
            child: selected ? activeIcon : icon,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: t.labelSmall?.copyWith(
              color: color,
              fontSize: 9,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
