String getPlayerRankFromStats({
  required int totalCorrect,
  required int totalWrong,
  required int totalGames,
  required int bestWinStreak,
}) {
  if (totalGames <= 0) return 'Observer';
  if (totalGames == 1) return 'Starborn';

  final double winRate = totalCorrect / totalGames;

  // Prestige: streak + enough games + not a total fluke
  if (totalGames >= 15) {
    if (bestWinStreak >= 7 && winRate >= 0.60) return 'The Chosen';
    if (bestWinStreak >= 5 && winRate >= 0.55) return 'Oracle';
    if (bestWinStreak >= 3 && winRate >= 0.50) return 'Fortune Teller';
    if (bestWinStreak >= 2 && winRate >= 0.45) return 'Luck Box';
  }

  // Skill: win rate tiers (requires sample size)
  if (totalGames >= 20) {
    if (winRate >= 0.80) return 'Clairvoyant';
    if (winRate >= 0.70) return 'Starbound';
    if (winRate >= 0.60) return 'Visionary';
  } else if (totalGames >= 10) {
    if (winRate >= 0.75) return 'Starbound';
    if (winRate >= 0.65) return 'Visionary';
    if (winRate >= 0.55) return 'Pattern Finder';
  } else if (totalGames >= 5) {
    if (winRate >= 0.70) return 'Visionary';
    if (winRate >= 0.55) return 'Awakened';
  }

  // Neutral / balanced
  if (totalGames >= 10 && (winRate - 0.5).abs() <= 0.07) {
    return 'Coin Flipper';
  }

  // Clouded: slightly negative
  if (totalGames >= 8 && winRate < 0.50 && winRate >= 0.40) {
    return 'Clouded';
  }

  // Optional middle tier
  if (totalGames >= 10 && winRate < 0.40 && winRate >= 0.35) {
    return 'Fogbound';
  }

  // Unlucky: true downswing
  if (totalGames >= 10 && winRate < 0.35) {
    return 'Unlucky';
  }

  // Give active players a meaningful default
  if (totalGames >= 10) return 'Seeker';

  return 'Contender';
}
