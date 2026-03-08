String formatEpochDisplay({required BigInt firstEpochInChain, required BigInt epoch}) {
  // Same epoch → show single value
  if (firstEpochInChain == epoch) {
    return epoch.toString();
  }

  // Range
  return '${firstEpochInChain.toString()}~${epoch.toString()}';
}
