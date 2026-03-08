import 'dart:convert';

class ProfileStatsModel {
  const ProfileStatsModel({
    required this.handle,
    required this.totalLosses,
    required this.totalWins,
    required this.totalWageredLamports,
    required this.totalWinPortionWageredLamports,
    required this.totalPayoutLamports,
    required this.bestWinStreak,
    required this.currentWinStreak,
    required this.lastPlayedTier,
    required this.lastResult,
    required this.lastResultEpoch,
    required this.createdAt,
    required this.updatedAt,
  });

  final String handle;

  final int totalLosses;
  final int totalWins;

  final int totalWageredLamports;
  final int totalWinPortionWageredLamports;
  final int totalPayoutLamports;

  final int bestWinStreak;
  final int currentWinStreak;

  final int lastPlayedTier;
  final String lastResult;
  final int lastResultEpoch;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// ----------------------------
  /// Derived helpers
  /// ----------------------------

  int get totalProfitLamports => totalPayoutLamports - totalWageredLamports;

  double get winRate {
    final totalGames = totalWins + totalLosses;
    if (totalGames == 0) return 0;
    return totalWins / totalGames;
  }

  /// ----------------------------
  /// JSON Parsing
  /// ----------------------------

  factory ProfileStatsModel.fromApiEnvelope(Map<String, dynamic> envelope) {
    // If API already returns direct JSON: { ok:true, item:{...} }
    if (envelope.containsKey('item')) {
      if (envelope['ok'] != null && envelope['ok'] != true) {
        throw Exception('ProfileStatsModel: API returned ok=false');
      }
      final item = envelope['item'] as Map<String, dynamic>;
      return ProfileStatsModel.fromJson(item);
    }

    // Lambda proxy style: { body: "{...}" }
    final bodyStr = envelope['body'];
    if (bodyStr is! String) {
      throw Exception('Invalid API response: missing body');
    }

    final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;
    if (bodyJson['ok'] != true) {
      throw Exception('ProfileStatsModel: API returned ok=false');
    }

    final item = bodyJson['item'] as Map<String, dynamic>;
    return ProfileStatsModel.fromJson(item);
  }

  factory ProfileStatsModel.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    String s(String key, [String fallback = '—']) => (json[key] as String?) ?? fallback;

    DateTime dt(String key) {
      final v = json[key] as String?;
      if (v == null || v.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return DateTime.parse(v);
    }

    return ProfileStatsModel(
      handle: s('handle', ''),

      totalLosses: n('totalLosses'),
      totalWins: n('totalWins'),

      totalWageredLamports: n('totalWageredLamports'),
      totalWinPortionWageredLamports: n('totalWinPortionWageredLamports'),
      totalPayoutLamports: n('totalPayoutLamports'),

      bestWinStreak: n('bestWinStreak'),
      currentWinStreak: n('currentWinStreak'),

      lastPlayedTier: n('lastPlayedTier'),
      lastResult: s('lastResult', '—'),
      lastResultEpoch: n('lastResultEpoch'),

      createdAt: dt('createdAt'),
      updatedAt: dt('updatedAt'),
    );
  }

  /// Used by provider to avoid unnecessary UI rebuilds.
  bool sameAs(ProfileStatsModel other) {
    return handle == other.handle &&
        totalLosses == other.totalLosses &&
        totalWins == other.totalWins &&
        totalWageredLamports == other.totalWageredLamports &&
        totalWinPortionWageredLamports == other.totalWinPortionWageredLamports &&
        totalPayoutLamports == other.totalPayoutLamports &&
        bestWinStreak == other.bestWinStreak &&
        currentWinStreak == other.currentWinStreak &&
        lastPlayedTier == other.lastPlayedTier &&
        lastResult == other.lastResult &&
        lastResultEpoch == other.lastResultEpoch &&
        updatedAt == other.updatedAt;
  }
}
