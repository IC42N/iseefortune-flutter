import 'package:flutter/material.dart';

class TableHeader extends StatelessWidget {
  const TableHeader({super.key, required this.title, required this.countText, this.rightText = ''});
  final String title;
  final String countText;
  final String rightText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Text(
            '$title ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          Text(
            countText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white60, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (rightText.isNotEmpty)
            Text(
              rightText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }
}
