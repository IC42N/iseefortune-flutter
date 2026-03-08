import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Text(
      '© $year · I SEE FORTUNE',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacityCompat(0.30),
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    );
  }
}
