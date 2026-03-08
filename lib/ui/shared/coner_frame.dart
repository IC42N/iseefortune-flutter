import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CornerFrame extends StatelessWidget {
  const CornerFrame({super.key, required this.asset, this.size = 22, this.inset = 8, this.opacity = 0.9});

  final String asset;
  final double size;
  final double inset;
  final double opacity;

  Widget _corner({double sx = 1, double sy = 1}) {
    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(sx, sy, 1.0, 1.0),
        child: SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand, // important so Positioned corners have a box to live in
        children: [
          Positioned(left: inset, top: inset, child: _corner(sx: -1, sy: -1)), // top-left
          Positioned(right: inset, top: inset, child: _corner(sx: 1, sy: -1)), // top-right
          Positioned(left: inset, bottom: inset, child: _corner(sx: -1, sy: 1)), // bottom-left
          Positioned(right: inset, bottom: inset, child: _corner(sx: 1, sy: 1)), // bottom-right (default)
        ],
      ),
    );
  }
}
