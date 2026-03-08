// lib/ui/history/game_history.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/winning_history_row.dart';
import 'package:iseefortune_flutter/providers/game/resolved_game_panel_provider.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/providers/game_history_provider.dart';
import 'package:iseefortune_flutter/ui/history/widgets/history_epoch_scroller.dart';
import 'package:iseefortune_flutter/ui/history/widgets/resolved_game_panel.dart';

/// Game history screen:
///  - top horizontal scroller (epochs + winning numbers)
///  - below: resolved game panel (mirrors web layout)
///
/// This file should stay "thin": orchestration + layout only.
/// All UI components live in /ui/history/widgets/.
class GameHistoryPage extends StatefulWidget {
  const GameHistoryPage({super.key});

  @override
  State<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends State<GameHistoryPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Optional safety: start history fetch if not already started.
    // If you already call GameHistoryProvider.start() in RootShell, you can delete this block.
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<GameHistoryProvider>().start();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<GameHistoryProvider, bool>((p) => p.isLoading);
    final err = context.select<GameHistoryProvider, Object?>((p) => p.lastError);

    final rows = context.select<GameHistoryProvider, List<WinningHistoryRow>>((p) => p.winningHistory);
    final selectedEpoch = context.select<GameHistoryProvider, BigInt?>((p) => p.selectedEpoch);

    return SafeArea(
      top: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // Top horizontal scroller (epochs)
          HistoryEpochScroller(
            rows: rows,
            selectedEpoch: selectedEpoch,
            isLoading: isLoading,
            error: err,
            onSelect: (e) {
              context.read<GameHistoryProvider>().selectEpoch(e);
              unawaited(context.read<ResolvedGamePanelProvider>().loadForSelectedEpoch(e));
            },
            onRefresh: () => context.read<GameHistoryProvider>().refresh(),
          ),

          const SizedBox(height: 11),

          // Below: resolved game panel
          const Expanded(child: ResolvedGamePanel()),

          const SizedBox(height: 11),
        ],
      ),
    );
  }
}
