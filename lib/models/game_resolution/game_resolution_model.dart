import 'package:solana/solana.dart';

enum GameResolutionOutcome {
  rollover,
  generic, // not connected OR didn't play
  win,
  loss,
}

class GameResolutionResult {
  const GameResolutionResult({
    required this.winningNumber,
    required this.outcome,
    this.rolloverNumbers,
    this.winnersCount,
    this.payoutLamports,
    this.predictionPda,
    this.messageOverride,
  });

  final int winningNumber;
  final GameResolutionOutcome outcome;

  /// When outcome == rollover, this holds the two rollover numbers (0..9).
  final List<int>? rolloverNumbers;

  // Optional extras if you have them later:
  final int? winnersCount;
  final int? payoutLamports;
  final String? predictionPda;

  // For custom copy in tests
  final String? messageOverride;
}

class GameResolutionModalArgs {
  const GameResolutionModalArgs({
    required this.anchorEpoch,
    required this.resolvedGamePda,
    required this.walletConnected,
    required this.playerPlayed,
    this.playerWon,
  });

  final int anchorEpoch;
  final Ed25519HDPublicKey resolvedGamePda;

  // Testing knobs / later derived from providers:
  final bool walletConnected;
  final bool playerPlayed;
  final bool? playerWon; // only meaningful if playerPlayed==true
}
