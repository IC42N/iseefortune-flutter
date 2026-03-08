String percentOfPotText(BigInt payout, BigInt netPot) {
  if (netPot == BigInt.zero) return '0%';

  // multiply by 10000 to preserve 2 decimal precision
  final scaled = payout * BigInt.from(10000) ~/ netPot;

  final whole = scaled ~/ BigInt.from(100);
  final decimals = (scaled % BigInt.from(100)).toInt();

  if (decimals == 0) {
    return '$whole%';
  }

  if (decimals % 10 == 0) {
    return '$whole.${decimals ~/ 10}%';
  }

  return '$whole.${decimals.toString().padLeft(2, '0')}%';
}
