import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

Widget darkButton({required String label, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.fromRGBO(255, 255, 255, 0.12), Color.fromRGBO(255, 255, 255, 0.06)],
        ),
        border: Border.all(color: Colors.white.withOpacityCompat(0.14), width: 1),
        boxShadow: [
          // outer shadow
          const BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 18, offset: Offset(0, 8)),
          // inset highlight (fake inset)
          BoxShadow(color: Colors.white.withOpacityCompat(0.06), blurRadius: 0, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color.fromRGBO(255, 255, 255, 0.9),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}
