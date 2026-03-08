import 'package:flutter/material.dart';
import 'help_modal.dart';

class HelpTap extends StatelessWidget {
  const HelpTap({
    super.key,
    required this.child,
    required this.title,
    required this.message,
    this.bullets,
    this.enabled = true,
    this.hitPadding = const EdgeInsets.all(6),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget child;
  final String title;
  final String message;
  final List<String>? bullets;

  final bool enabled;
  final EdgeInsets hitPadding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return InkWell(
      borderRadius: borderRadius,
      onTap: () => showHelpModal(context, title: title, message: message, bullets: bullets),
      child: Padding(padding: hitPadding, child: child),
    );
  }
}
