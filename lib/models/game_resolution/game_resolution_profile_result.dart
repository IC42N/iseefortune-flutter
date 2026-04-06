class ResolvedGameProfileResult {
  const ResolvedGameProfileResult({
    required this.gameEpoch,
    required this.tier,
    required this.resolvedEpoch,
    required this.winningNumber,
    this.actionString,
    this.rolloverReasonText,
  });

  final BigInt gameEpoch;
  final int tier;
  final BigInt? resolvedEpoch;
  final int? winningNumber;
  final String? actionString;
  final String? rolloverReasonText;

  factory ResolvedGameProfileResult.fromJson(Map<String, dynamic> json) {
    return ResolvedGameProfileResult(
      gameEpoch: BigInt.from((json['gameEpoch'] as num).toInt()),
      tier: (json['tier'] as num).toInt(),
      resolvedEpoch: json['resolvedEpoch'] == null
          ? null
          : BigInt.from((json['resolvedEpoch'] as num).toInt()),
      winningNumber: (json['winningNumber'] as num?)?.toInt(),
      actionString: json['actionString'] as String?,
      rolloverReasonText: json['rolloverReasonText'] as String?,
    );
  }
}

class ResolvedGameLookupKey {
  const ResolvedGameLookupKey({required this.gameEpoch, required this.tier});

  final BigInt gameEpoch;
  final int tier;

  String toApiKey() => '${gameEpoch.toString()}:$tier';
}
