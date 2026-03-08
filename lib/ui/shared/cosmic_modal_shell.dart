// lib/ui/shared/cosmic_modal_shell.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:iseefortune_flutter/ui/shared/cosmic_orbit_border.dart';
import 'package:iseefortune_flutter/ui/shared/floating_stars_overlay.dart';
import 'package:iseefortune_flutter/ui/shared/floaty.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class CosmicModalShell extends StatelessWidget {
  const CosmicModalShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.hueDeg,
    this.rightAction,
    this.overhang,
    this.overhangLift = 28,
    this.radius = 24,
    this.showHands = true,
    this.handsTop = 26.0,
    this.floatingHands = false,
    this.showClouds = true,
    this.showStars = false,
  });

  final String title;
  final String? subtitle;
  final int? hueDeg;
  final Widget child;
  final Widget? rightAction;
  final bool showHands;
  final double handsTop;
  final bool floatingHands;
  final bool showClouds;
  final bool showStars;

  final Widget? overhang;
  final double overhangLift;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = media.size.height * 0.92;

    final cloudSize = 70.0;
    const cloudColor = AppColors.goldColor;
    const opacity = 0.85;

    const padding = EdgeInsets.all(3);
    const topLeft = 'assets/svg/clouds/cloud-tl.svg';
    const topRight = 'assets/svg/clouds/cloud-tr.svg';
    const bottomLeft = 'assets/svg/clouds/cloud-bl.svg';
    const bottomRight = 'assets/svg/clouds/cloud-br.svg';

    //Hands
    const handSize = 80.0;
    //const handTop = 26.0;
    const handInset = 70.0;
    const handRotate = 22;
    const leftHand = 'assets/svg/hands/left-hand.svg';

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(left: 12, right: 12, bottom: 12 + media.viewInsets.bottom),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // This ConstrainedBox caps height but does NOT force full height.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: CosmicOrbitBorder(
                  radius: radius,
                  strokeWidth: 2.6,
                  duration: const Duration(milliseconds: 4000), // closer to your 4s rotate
                  baseOpacity: 0.10,
                  ringOpacity: 0.75,
                  glowOpacity: 0.90,
                  glowSigma: 62,
                  pulseAmount: 0.18,
                  pulseSpeed: 0.50, // slower “breathing”
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacityCompat(0.55),
                            blurRadius: 34,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),

                      // Dynamic height: content wraps until it hits maxH, then scrolls.
                      child: SingleChildScrollView(
                        // keeps it shrink-wrapped when short, scrolls when tall
                        physics: const BouncingScrollPhysics(),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),

              // Clouds overlay. Positioned.fill means it doesn't affect layout size.
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      // Only show hands with overhang
                      if (showHands)
                        Positioned(
                          left: handInset,
                          top: handsTop,
                          child: Floaty(
                            child: Opacity(
                              opacity: opacity,
                              child: Transform.rotate(
                                angle: 8 * math.pi / handRotate,
                                child: SvgPicture.asset(
                                  leftHand,
                                  width: handSize,
                                  height: handSize,
                                  colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (showHands)
                        Positioned(
                          right: handInset,
                          top: handsTop,
                          child: Floaty(
                            child: Opacity(
                              opacity: opacity,
                              child: Transform.rotate(
                                angle: -8 * math.pi / handRotate,
                                child: Transform.scale(
                                  scaleX: -1,
                                  child: SvgPicture.asset(
                                    leftHand,
                                    width: handSize,
                                    height: handSize,
                                    colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Clouds
                      if (showClouds)
                        Positioned(
                          left: padding.left,
                          top: padding.top,
                          child: Opacity(
                            opacity: opacity,
                            child: SvgPicture.asset(
                              topLeft,
                              width: cloudSize,
                              height: cloudSize,
                              colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                            ),
                          ),
                        ),

                      if (showClouds)
                        Positioned(
                          right: padding.right,
                          top: padding.top,
                          child: Opacity(
                            opacity: opacity,
                            child: SvgPicture.asset(
                              topRight,
                              width: cloudSize,
                              height: cloudSize,
                              colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                            ),
                          ),
                        ),

                      if (showClouds)
                        Positioned(
                          left: padding.left,
                          bottom: padding.bottom,
                          child: Opacity(
                            opacity: opacity,
                            child: SvgPicture.asset(
                              bottomLeft,
                              width: cloudSize,
                              height: cloudSize,
                              colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      if (showClouds)
                        Positioned(
                          right: padding.right,
                          bottom: padding.bottom,
                          child: Opacity(
                            opacity: opacity,
                            child: SvgPicture.asset(
                              bottomRight,
                              width: cloudSize,
                              height: cloudSize,
                              colorFilter: const ColorFilter.mode(cloudColor, BlendMode.srcIn),
                            ),
                          ),
                        ),

                      // Stars overlay (floats upward)
                      if (showStars)
                        Positioned.fill(
                          child: FloatingStarsOverlay(
                            starCount: 40,
                            speed: 0.02,
                            opacity: 0.68,
                            minSize: 0.80,
                            maxSize: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Overhang rendered outside the clip
              if (overhang != null) Positioned(left: 0, right: 0, top: -overhangLift, child: overhang!),
            ],
          ),
        ),
      ),
    );
  }
}
