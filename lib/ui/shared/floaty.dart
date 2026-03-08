import 'package:flutter/material.dart';

class Floaty extends StatefulWidget {
  const Floaty({super.key, required this.child});
  final Widget child;

  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _dy;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);

    _dy = Tween<double>(
      begin: 0.0,
      end: -5.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Transform.translate(offset: Offset(0, _dy.value), child: child);
      },
      child: widget.child,
    );
  }
}
