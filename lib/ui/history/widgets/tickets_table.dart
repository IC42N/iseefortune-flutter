import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/game/game_db_model.dart';

class TicketsTable extends StatelessWidget {
  const TicketsTable({super.key, required this.tickets});

  final List<ApiTicketRow> tickets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Player',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Tickets',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tickets.map((t) {
            final count = t.rewarded;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.player,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
