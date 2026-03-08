enum ResolutionPhase { idle, waitingOnChain, revealing, finalized, rollover, error }

class GameResolutionState {
  final ResolutionPhase phase;
  final int? winningNumber;
  final String message;
  final bool playerPlayed;
  final bool playerWon;
  final String? error;

  const GameResolutionState({
    required this.phase,
    this.winningNumber,
    this.message = '',
    this.playerPlayed = false,
    this.playerWon = false,
    this.error,
  });

  GameResolutionState copyWith({
    ResolutionPhase? phase,
    int? winningNumber,
    String? message,
    bool? playerPlayed,
    bool? playerWon,
    String? error,
  }) {
    return GameResolutionState(
      phase: phase ?? this.phase,
      winningNumber: winningNumber ?? this.winningNumber,
      message: message ?? this.message,
      playerPlayed: playerPlayed ?? this.playerPlayed,
      playerWon: playerWon ?? this.playerWon,
      error: error ?? this.error,
    );
  }

  static const idle = GameResolutionState(phase: ResolutionPhase.idle);
}
