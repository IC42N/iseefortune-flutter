import 'dart:ui';
import 'package:flutter/material.dart';

class CardShell extends StatelessWidget {
  const CardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.radius = 10,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // blur(10px)
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),

            // === GRADIENT ===
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(255, 255, 255, 0.045), Color.fromRGBO(255, 255, 255, 0.02)],
            ),

            // === BORDER ===
            border: Border.all(color: Color.fromRGBO(255, 255, 255, 0.08), width: 1),

            // === SHADOWS ===
            boxShadow: const [
              // Drop shadow
              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.22), blurRadius: 14, offset: Offset(0, 4)),

              // Inset highlight (approximation)
              BoxShadow(
                color: Color.fromRGBO(255, 255, 255, 0.035),
                blurRadius: 0,
                offset: Offset(0, 1),
                spreadRadius: -1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
