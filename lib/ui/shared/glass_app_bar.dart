import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.blur = 3,
    this.opacity = 0.05,
    this.height = kToolbarHeight,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;
  final double blur;
  final double opacity;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: AppBar(
          elevation: 0,
          leading: leading,
          backgroundColor: const Color.fromARGB(255, 14, 26, 37),
          title: title,
          actions: actions,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black.withOpacityCompat(0.45), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
