import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class Slogan extends StatelessWidget {
  const Slogan({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'A game for those who trust no one',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacityCompat(0.35),
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }
}
