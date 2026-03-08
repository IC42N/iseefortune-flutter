import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/shared/cosmic_modal_shell.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class CosmicModal {
  const CosmicModal._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    int? hueDeg, // optional glow hue (0..360)
    String? subtitle,
    Widget? rightAction, // optional button on the right of header
    Widget? overhang,
    double? overhangLift,
    bool isScrollControlled = true,
    bool enableDrag = true,
    bool useRootNavigator = true,
    bool showClouds = true,
    bool showHands = true,
    double handsTop = 26.0,
    double radius = 24,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacityCompat(0.55),
      builder: (_) {
        return CosmicModalShell(
          title: title,
          subtitle: subtitle,
          hueDeg: hueDeg,
          rightAction: rightAction,
          overhang: overhang,
          overhangLift: overhangLift ?? 28,
          radius: radius,
          showClouds: showClouds,
          showHands: showHands,
          handsTop: handsTop,
          child: child,
        );
      },
    );
  }
}
