import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class BulletedList extends StatelessWidget {
  const BulletedList({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacityCompat(0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t,
                  style: TextStyle(
                    color: Colors.white.withOpacityCompat(0.70),
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
