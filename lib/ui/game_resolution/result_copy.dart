import 'package:iseefortune_flutter/utils/solana/lamports.dart';

enum ResultTone { hype, encouraging, sympathetic, playful, cosmic, streak, neutral }

class ResultCopyContext {
  const ResultCopyContext({
    required this.outcome, // "win" | "miss"
    this.betLamports,
    this.payoutLamports,
    this.winStreak,
    this.isRollover,
    this.seed,
  });

  final String outcome;
  final BigInt? betLamports;
  final BigInt? payoutLamports;
  final int? winStreak;
  final bool? isRollover;
  final Object? seed;
}

class ResultCopy {
  const ResultCopy({required this.tone, required this.headline, this.body});

  final ResultTone tone;
  final String headline;
  final String? body;
}

class CopyLine {
  const CopyLine(this.headline, [this.body]);

  final String headline;
  final String? body;
}

// ----- copy tables -----

const Map<ResultTone, List<CopyLine>> missCopy = {
  ResultTone.encouraging: [
    CopyLine('So close', 'Next epoch is yours'),
    CopyLine('Not this time', 'Run it back next round'),
    CopyLine('Missed it', 'Odds reset every epoch'),
  ],
  ResultTone.sympathetic: [
    CopyLine('Oof that hurts', 'Sorry, better luck next epoch'),
    CopyLine('Rough miss', 'We feel that one'),
    CopyLine('Painful', 'Shake it off — next round'),
  ],
  ResultTone.playful: [
    CopyLine('The dice said no', 'Try again next epoch'),
    CopyLine('That one slipped', 'Next epoch soon'),
  ],
  ResultTone.cosmic: [
    CopyLine('The gods chose a different path', 'Their favor shifts with time'),
    CopyLine('The stars aligned elsewhere', 'Next epoch, new fate'),
    CopyLine('The gods listened…', 'But answered another name'),
    CopyLine('The gods demand more conviction', 'The offering was not yet enough'),
  ],
  ResultTone.neutral: [CopyLine('Missed this round', 'Try again next epoch')],
};

const Map<ResultTone, List<CopyLine>> winCopy = {
  ResultTone.hype: [
    CopyLine('Luck favored you', ''),
    CopyLine('Perfect call', ''),
    CopyLine('Nailed it', ''),
    CopyLine('Perfect execution', ''),

    CopyLine('Victory', ''),
    CopyLine('Fate aligned in your favor!', ''),

    CopyLine('You won!', ''),
    CopyLine('That\'s a clean hit', ''),

    CopyLine('Winner!', ''),
    CopyLine('Winner winner chicken dinner', ''),
    CopyLine('You called it!', ''),
  ],

  ResultTone.cosmic: [
    CopyLine('Divine favor', ''),
    CopyLine('You are on the right path', ''),

    CopyLine('The gods chose you', ''),
    CopyLine('The stars aligned', ''),
    CopyLine('This moment was written', ''),

    CopyLine('Destiny delivered', ''),
    CopyLine('You were meant for this', ''),

    CopyLine('The stars chose you', ''),
    CopyLine('This moment was written', ''),
  ],

  ResultTone.streak: [
    CopyLine('The gods are watching', ''),
    CopyLine('You\'re on their path now', ''),

    CopyLine('The streak continues', ''),
    CopyLine('Keep the momentum going', ''),

    CopyLine('Blessed again', ''),
    CopyLine('This isn\'t random anymore', ''),
  ],

  ResultTone.neutral: [CopyLine('You won!', ''), CopyLine('Fate aligned in your favor', '')],
};
const Map<ResultTone, List<CopyLine>> rolloverCopy = {
  ResultTone.cosmic: [
    CopyLine('The gods turned the page', 'The story continues'),
    CopyLine('The gods postponed the verdict', 'Return next epoch'),
    CopyLine(
      'The pot hungers',
      'The offering wasn\'t enough to force a verdict. It pulls us into the next epoch.',
    ),
    CopyLine('Verdict delayed', 'The cosmos withholds the answer. More conviction is required.'),
    CopyLine('Deeper gravity', 'The pot demands more. The outcome slips into the next epoch — deeper we go.'),
  ],
  ResultTone.neutral: [CopyLine('Rollover', 'No final verdict this round. Moving on to the next epoch.')],
};
// ----- helpers (mirrors TS) -----

int _hashSeedToInt(Object? seed) {
  final s = seed == null ? '0' : seed.toString();
  int h = 2166136261; // FNV-1a 32-bit offset basis
  for (int i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xFFFFFFFF; // keep 32-bit
  }
  return h >>> 0;
}

T _pick<T>(List<T> arr, int seedInt) => arr[seedInt % arr.length];

double _lamportsToSol(BigInt lamports) => lamports.toDouble() / 1e9;

ResultTone _chooseMissTone(ResultCopyContext ctx) {
  final betSol = ctx.betLamports == null ? 0.0 : _lamportsToSol(ctx.betLamports!);
  return betSol >= 1.0 ? ResultTone.sympathetic : ResultTone.encouraging;
}

ResultTone _maybeSpiceEncouragingTone(ResultTone base, int seedInt) {
  if (base != ResultTone.encouraging) return base;
  final r = seedInt % 20; // 0..19
  if (r == 0 || r == 1) return ResultTone.cosmic; // ~10%
  if (r == 2 || r == 3) return ResultTone.playful; // ~10%
  return base;
}

ResultTone _chooseRolloverTone(int seedInt) {
  return (seedInt % 10) < 8 ? ResultTone.cosmic : ResultTone.neutral; // 80/20
}

ResultTone _chooseWinTone(ResultCopyContext ctx, int seedInt) {
  final streak = ctx.winStreak ?? 0;
  if (streak >= 2) return ResultTone.streak;

  final payoutSol = ctx.payoutLamports == null ? 0.0 : _lamportsToSol(ctx.payoutLamports!);

  if (payoutSol > 0 && payoutSol < 1) {
    return (seedInt % 5 == 0) ? ResultTone.cosmic : ResultTone.neutral;
  }
  if (payoutSol >= 1) return ResultTone.hype;

  return ResultTone.neutral;
}

// ----- main -----

ResultCopy getResultCopy(ResultCopyContext ctx) {
  final seedInt = _hashSeedToInt(ctx.seed);

  if (ctx.isRollover == true) {
    final tone = _chooseRolloverTone(seedInt);
    final line = _pick(rolloverCopy[tone]!, seedInt);
    return ResultCopy(tone: tone, headline: line.headline, body: line.body);
  }

  if (ctx.outcome == 'win') {
    final tone = _chooseWinTone(ctx, seedInt);
    final line = _pick(winCopy[tone]!, seedInt);
    final payout = ctx.payoutLamports ?? BigInt.zero;
    final sol = lamportsToSolText(payout);
    return ResultCopy(tone: tone, headline: line.headline, body: '+$sol SOL');
  }

  final base = _chooseMissTone(ctx);
  final tone = _maybeSpiceEncouragingTone(base, seedInt);
  final line = _pick(missCopy[tone]!, seedInt);
  return ResultCopy(tone: tone, headline: line.headline, body: line.body);
}
