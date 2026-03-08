class ApiResolvedGameDto {
  ApiResolvedGameDto({required this.gameEpoch, required this.tier, required this.core, required this.extras});

  final int gameEpoch;
  final int tier;
  final ApiResolvedGameCore core;
  final ApiResolvedGameExtras extras;

  int get status => 2; // resolved
  int get winningNumber => core.winningNumber;

  BigInt get netPrizePoolLamports => core.netPotLamports;
  BigInt get grossPotLamports => core.grossPotLamports;
  BigInt get feeLamports => core.feeLamports;
  int get feeBps => core.feeBps;

  int get totalWinners => core.winnersCount;
  int get totalLosers => core.losersCount;

  DateTime? get resolvedAt => core.updatedAt ?? core.createdAt;

  String? get resultsUri => core.arweaveResultsUri;
  int get secondaryRolloverNumber => core.secondaryRolloverNumber;

  bool get isRollover => core.actionString == "ROLLOVER";

  factory ApiResolvedGameDto.fromJson(Map<String, dynamic> j) {
    return ApiResolvedGameDto(
      gameEpoch: (j['gameEpoch'] as num).toInt(),
      tier: (j['tier'] as num).toInt(),
      core: ApiResolvedGameCore.fromJson(j['core'] as Map<String, dynamic>),
      extras: ApiResolvedGameExtras.fromJson((j['extras'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

class ApiResolvedGameCore {
  ApiResolvedGameCore({
    required this.gameEpoch,
    required this.tier,
    required this.winningNumber,
    required this.winnersCount,
    required this.losersCount,
    required this.netPotLamports,
    required this.grossPotLamports,
    required this.feeLamports,
    required this.feeBps,
    required this.gamePda,
    required this.arweaveResultsUri,
    required this.merkleRootBase64,
    required this.rngBlockhashBase58,
    required this.resolveTxSignature,
    required this.createdAt,
    required this.updatedAt,
    required this.secondaryRolloverNumber,
    required this.endSlot,
    required this.firstEpoch,
    required this.lastEpoch,
    required this.actionString,
    required this.rolloverReasonText,
  });

  final int gameEpoch;
  final int tier;
  final int winningNumber;
  final int winnersCount;
  final int losersCount;

  final BigInt netPotLamports;
  final BigInt grossPotLamports;
  final BigInt feeLamports;
  final int feeBps;

  final String gamePda;
  final String? arweaveResultsUri;

  // Keep it here if you want, but do NOT map it into History bundle.
  final String merkleRootBase64;

  final String rngBlockhashBase58;
  final String resolveTxSignature;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final int secondaryRolloverNumber;

  // Extra useful fields that exist in your payload
  final BigInt endSlot;
  final int firstEpoch;
  final int lastEpoch;

  final String actionString;
  final String rolloverReasonText;

  static BigInt _big(dynamic v) {
    if (v == null) return BigInt.zero;
    if (v is BigInt) return v;
    if (v is int) return BigInt.from(v);
    if (v is num) return BigInt.from(v.toInt());
    if (v is String) return BigInt.parse(v);
    throw FormatException('Invalid bigint: $v');
  }

  static DateTime? _dt(dynamic v) => (v is String) ? DateTime.tryParse(v) : null;

  factory ApiResolvedGameCore.fromJson(Map<String, dynamic> j) {
    return ApiResolvedGameCore(
      gameEpoch: (j['gameEpoch'] as num).toInt(),
      tier: (j['tier'] as num).toInt(),
      winningNumber: (j['winningNumber'] as num).toInt(),
      winnersCount: (j['winnersCount'] as num?)?.toInt() ?? 0,
      losersCount: (j['losersCount'] as num?)?.toInt() ?? 0,

      netPotLamports: _big(j['netPotLamports']),
      grossPotLamports: _big(j['grossPotLamports']),
      feeLamports: _big(j['feeLamports']),
      feeBps: (j['feeBps'] as num?)?.toInt() ?? 0,

      gamePda: (j['gamePDA'] as String?) ?? (j['gamePda'] as String?) ?? "",
      arweaveResultsUri: j['arweaveResultsUri'] as String?,

      merkleRootBase64: (j['merkleRootBase64'] as String?) ?? "",
      rngBlockhashBase58: (j['rngBlockhashBase58'] as String?) ?? "",
      resolveTxSignature: (j['resolveTxSignature'] as String?) ?? "",

      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
      secondaryRolloverNumber: (j['secondaryRolloverNumber'] as num).toInt(),

      endSlot: _big(j['endSlot']),
      firstEpoch: (j['firstEpoch'] as num?)?.toInt() ?? 0,
      lastEpoch: (j['resolvedEpoch'] as num?)?.toInt() ?? 0,

      actionString: (j['actionString'] as String?) ?? "",
      rolloverReasonText: (j['rolloverReasonText'] as String?) ?? "",
    );
  }
}

class ApiResolvedGameExtras {
  ApiResolvedGameExtras({required this.winners, required this.tickets, required this.keys});

  final List<ApiWinnerRow> winners;
  final List<ApiTicketRow> tickets;
  final Map<String, dynamic> keys;

  factory ApiResolvedGameExtras.fromJson(Map<String, dynamic> j) {
    final winnersRaw = (j['winners'] as List?) ?? const [];
    final ticketsRaw = (j['tickets'] as List?) ?? const [];
    final keysRaw = (j['keys'] is Map)
        ? Map<String, dynamic>.from(j['keys'] as Map)
        : const <String, dynamic>{};

    return ApiResolvedGameExtras(
      winners: winnersRaw
          .whereType<Map>()
          .map((m) => ApiWinnerRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),

      tickets: ticketsRaw
          .whereType<Map>()
          .map((m) => ApiTicketRow.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false),

      keys: keysRaw,
    );
  }
}

class ApiWinnerRow {
  ApiWinnerRow({
    required this.player,
    required this.wagerTotalLamports,
    required this.wagerWinPortionLamports,
    required this.payoutLamports,
    required this.changedCount,
  });

  final String player;
  final BigInt wagerTotalLamports;
  final BigInt wagerWinPortionLamports;
  final BigInt payoutLamports;
  final int changedCount;

  static BigInt _big(dynamic v) {
    if (v == null) return BigInt.zero;
    if (v is BigInt) return v;
    if (v is int) return BigInt.from(v);
    if (v is num) return BigInt.from(v.toInt());
    if (v is String) return BigInt.parse(v);
    throw FormatException('Invalid bigint: $v');
  }

  factory ApiWinnerRow.fromJson(Map<String, dynamic> j) {
    return ApiWinnerRow(
      player: (j['player'] as String?) ?? "",
      wagerTotalLamports: _big(j['wager_total_lamports']),
      wagerWinPortionLamports: _big(j['wager_win_portion_lamports']),
      payoutLamports: _big(j['payout_lamports']),
      changedCount: (j['changed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiTicketRow {
  ApiTicketRow({
    required this.player,
    required this.epoch,
    required this.tier,
    required this.placedSlot,
    required this.lamports,
    required this.rewarded,
  });

  final String player;
  final int epoch;
  final int tier;
  final BigInt placedSlot;
  final BigInt lamports;
  final int rewarded;

  static BigInt _big(dynamic v) {
    if (v == null) return BigInt.zero;
    if (v is BigInt) return v;
    if (v is int) return BigInt.from(v);
    if (v is num) return BigInt.from(v.toInt());
    if (v is String) return BigInt.parse(v);
    throw FormatException('Invalid bigint: $v');
  }

  factory ApiTicketRow.fromJson(Map<String, dynamic> j) {
    return ApiTicketRow(
      player: (j['player'] as String?) ?? '',
      epoch: (j['epoch'] as num?)?.toInt() ?? 0,
      tier: (j['tier'] as num?)?.toInt() ?? 0,
      placedSlot: _big(j['placed_slot']),
      lamports: _big(j['lamports']),
      rewarded: (j['rewarded'] as num?)?.toInt() ?? 0,
    );
  }
}
