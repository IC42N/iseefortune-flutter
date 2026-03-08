import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/game_resolution/game_resolution_model.dart';
import 'package:iseefortune_flutter/ui/game_resolution/game_resolution_modal.dart';
import 'package:solana/solana.dart';

class GameResolutionDebugScreen extends StatefulWidget {
  const GameResolutionDebugScreen({super.key});

  @override
  State<GameResolutionDebugScreen> createState() => _GameResolutionDebugScreenState();
}

class _GameResolutionDebugScreenState extends State<GameResolutionDebugScreen> {
  bool walletConnected = true;
  bool playerPlayed = true;
  bool playerWon = false;
  bool rollover = false;

  int winningNumber = 9; // 0..9
  int epoch = 999;
  int tier = 1;

  int rolloverA = 2; // 0..9
  int rolloverB = 7; // 0..9

  Duration resolveDelay = const Duration(seconds: 2);

  Future<GameResolutionResult> _fakeResultFuture() async {
    await Future.delayed(resolveDelay);

    if (rollover) {
      return GameResolutionResult(
        winningNumber: winningNumber,
        outcome: GameResolutionOutcome.rollover,
        rolloverNumbers: [rolloverA, rolloverB],
      );
    }

    if (!walletConnected || !playerPlayed) {
      return GameResolutionResult(winningNumber: winningNumber, outcome: GameResolutionOutcome.generic);
    }

    return GameResolutionResult(
      winningNumber: winningNumber,
      outcome: playerWon ? GameResolutionOutcome.win : GameResolutionOutcome.loss,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dummy PDA for testing UI only (replace later)
    final dummy = Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111');

    final args = GameResolutionModalArgs(
      anchorEpoch: epoch,
      resolvedGamePda: dummy,
      walletConnected: walletConnected,
      playerPlayed: playerPlayed,
      playerWon: playerWon,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Resolution Modal Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Wallet Connected'),
            value: walletConnected,
            onChanged: (v) => setState(() {
              walletConnected = v;
              if (!walletConnected) {
                playerPlayed = false;
                playerWon = false;
              }
            }),
          ),
          SwitchListTile(
            title: const Text('Player Played'),
            value: playerPlayed,
            onChanged: walletConnected
                ? (v) => setState(() {
                    playerPlayed = v;
                    if (!playerPlayed) playerWon = false;
                  })
                : null,
          ),
          SwitchListTile(
            title: const Text('Player Won'),
            value: playerWon,
            onChanged: (walletConnected && playerPlayed) ? (v) => setState(() => playerWon = v) : null,
          ),
          SwitchListTile(
            title: const Text('Rollover'),
            value: rollover,
            onChanged: (v) => setState(() => rollover = v),
          ),

          const SizedBox(height: 8),

          // Epoch stepper
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Epoch'),
                  subtitle: Text('$epoch'),
                ),
              ),
              IconButton(
                tooltip: 'Epoch -1',
                onPressed: () => setState(() => epoch = (epoch - 1).clamp(0, 999999)),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                tooltip: 'Epoch +1',
                onPressed: () => setState(() => epoch += 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          // Tier stepper
          const SizedBox(height: 8),

          // Winning number
          ListTile(
            title: const Text('Winning Number'),
            subtitle: Text('$winningNumber'),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: winningNumber.toDouble(),
                min: 0,
                max: 9,
                divisions: 9,
                label: '$winningNumber',
                onChanged: (v) => setState(() => winningNumber = v.round()),
              ),
            ),
          ),

          // Rollover numbers
          if (rollover) ...[
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Rollover Number A'),
              subtitle: Text('$rolloverA'),
              trailing: SizedBox(
                width: 140,
                child: Slider(
                  value: rolloverA.toDouble(),
                  min: 0,
                  max: 9,
                  divisions: 9,
                  label: '$rolloverA',
                  onChanged: (v) => setState(() {
                    rolloverA = v.round();
                    if (rolloverA == rolloverB) rolloverB = (rolloverB + 1) % 10;
                  }),
                ),
              ),
            ),
            ListTile(
              title: const Text('Rollover Number B'),
              subtitle: Text('$rolloverB'),
              trailing: SizedBox(
                width: 140,
                child: Slider(
                  value: rolloverB.toDouble(),
                  min: 0,
                  max: 9,
                  divisions: 9,
                  label: '$rolloverB',
                  onChanged: (v) => setState(() {
                    rolloverB = v.round();
                    if (rolloverB == rolloverA) rolloverA = (rolloverA + 1) % 10;
                  }),
                ),
              ),
            ),
          ],

          // Delay
          ListTile(
            title: const Text('Resolve Delay (seconds)'),
            subtitle: Text('${resolveDelay.inSeconds}s'),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: resolveDelay.inSeconds.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '${resolveDelay.inSeconds}s',
                onChanged: (v) => setState(() => resolveDelay = Duration(seconds: v.round())),
              ),
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {
              GameResolutionModal.show(context, args: args, resultFutureOverride: _fakeResultFuture());
            },
            child: const Text('Open Modal'),
          ),
        ],
      ),
    );
  }
}
