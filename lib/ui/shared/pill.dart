import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class Pill extends StatelessWidget {
  const Pill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacityCompat(0.08),
        border: Border.all(color: Colors.white.withOpacityCompat(0.12)),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacityCompat(0.85), fontSize: 12)),
    );
  }
}
