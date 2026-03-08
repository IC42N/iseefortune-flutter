import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CornerClouds extends StatelessWidget {
  const CornerClouds({
    super.key,
    required this.child,
    this.topLeft = 'assets/svg/clouds/cloud-tl.svg',
    this.topRight = 'assets/svg/clouds/cloud-tr.svg',
    this.bottomLeft = 'assets/svg/clouds/cloud-bl.svg',
    this.bottomRight = 'assets/svg/clouds/cloud-br.svg',
    this.size = 140,
    this.opacity = 1,
    this.padding = const EdgeInsets.all(0),
  });

  final Widget child;

  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;

  /// cloud render size (square)
  final double size;

  /// subtle overlay so it doesn't fight the UI
  final double opacity;

  /// optional inset from corners (like safe padding)
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const cloudColor = Color(0xFFBFB47B);
    return Stack(
      children: [
        // --- Background layer: clouds ---
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  left: padding.left,
                  top: padding.top,
                  child: Opacity(
                    opacity: opacity,
                    child: SvgPicture.asset(
                      topLeft,
                      width: size,
                      height: size,
                      colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                Positioned(
                  right: padding.right,
                  top: padding.top,
                  child: Opacity(
                    opacity: opacity,
                    child: SvgPicture.asset(
                      topRight,
                      width: size,
                      height: size,
                      colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                Positioned(
                  left: padding.left,
                  bottom: padding.bottom,
                  child: Opacity(
                    opacity: opacity,
                    child: SvgPicture.asset(
                      bottomLeft,
                      width: size,
                      height: size,
                      colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                Positioned(
                  right: padding.right,
                  bottom: padding.bottom,
                  child: Opacity(
                    opacity: opacity,
                    child: SvgPicture.asset(
                      bottomRight,
                      width: size,
                      height: size,
                      colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Foreground layer: your actual page content ---
        Positioned.fill(child: child),
      ],
    );
  }
}
