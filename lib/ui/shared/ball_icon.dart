import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the ball SVG icon.
///
/// Opinion: keep the `color` param *actually used* so this widget is reusable.
/// If you always want gold, remove the param and hardcode AppConstants.goldColor.
Widget svgBall({
  required double size,
  required Color color,
  String assetPath = 'assets/svg/balls/ball-icon.svg',
}) {
  return SvgPicture.asset(
    assetPath,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
