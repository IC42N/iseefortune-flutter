int safeEpochToInt(BigInt epoch) {
  // epoch is u64 on-chain; Dart int can hold it on 64-bit platforms,
  // but toInt() can throw if too large in some contexts.
  // Solana epochs are nowhere near overflow, but we still guard.
  final max = BigInt.from(0x7FFFFFFFFFFFFFFF); // max signed 64-bit
  final e = epoch > max ? max : epoch;
  return e.toInt();
}
