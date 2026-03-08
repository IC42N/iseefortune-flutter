import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class TicketBanner extends StatelessWidget {
  const TicketBanner({super.key, required this.ticketsEarned});

  final int ticketsEarned;

  @override
  Widget build(BuildContext context) {
    final ticketText = ticketsEarned == 1
        ? 'You earned 1 change ticket!'
        : 'You earned $ticketsEarned tickets';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(color: const Color.fromARGB(255, 124, 216, 136).withOpacityCompat(0.25)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎟️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            ticketText,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color.fromARGB(255, 255, 236, 236).withOpacityCompat(0.95),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
