import 'package:iseefortune_flutter/models/live_feed_model.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';
//import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/rollover_number_rules.dart';

LiveFeedVM buildLiveFeedVM({required LiveFeedModel liveFeed, required int primaryRollOverNumber}) {
  // Selectable numbers
  final selectable = selectableNumbersFromRollover(
    primaryRollOverNumber: primaryRollOverNumber,
    secondaryRollOverNumber: liveFeed.secondaryRolloverNumber,
  );

  // total predictions among selectable
  int totalPredictions = 0;
  for (final n in selectable) {
    totalPredictions += liveFeed.betsPerNumber[n];
  }

  // ---- MOST POPULAR (max count) ----
  int maxCount = -1;
  for (final n in selectable) {
    final c = liveFeed.betsPerNumber[n];
    if (c > maxCount) maxCount = c;
  }

  final mostPopularAll = <int>[];
  if (maxCount >= 0) {
    for (final n in selectable) {
      if (liveFeed.betsPerNumber[n] == maxCount) mostPopularAll.add(n);
    }
  }

  // Keep full tie list; UI caps to 4 and shows "+N"
  final mostPopular = mostPopularAll;

  // ---- MOST PROFITABLE (min count) ----
  int minCount = 1 << 30;
  for (final n in selectable) {
    final c = liveFeed.betsPerNumber[n];
    if (c < minCount) minCount = c;
  }

  final mostProfitableAll = <int>[];
  for (final n in selectable) {
    if (liveFeed.betsPerNumber[n] == minCount) mostProfitableAll.add(n);
  }

  // Keep full tie list; UI caps to 4 and shows "+N"
  final mostProfitable = mostProfitableAll;

  // ---- STATS (8 tiles) ----
  final stats = <NumberStatVM>[];
  for (final n in selectable) {
    final count = liveFeed.betsPerNumber[n];
    final pct = totalPredictions == 0 ? 0.0 : (count / totalPredictions) * 100.0;

    stats.add(
      NumberStatVM(
        number: n,
        count: count,
        percent: pct,
        color: numberColor(n),
        isPopular: mostPopularAll.contains(n),
        lamportsPerNumber: liveFeed.lamportsPerNumber[n],
      ),
    );
  }

  // icLogger.w(
  //   'LiveFeedVM built: selectable=$selectable selectableCount=${selectable.length}  totalPredictions=$totalPredictions, popular=$mostPopular, profitable=$mostProfitable',
  // );

  return LiveFeedVM(
    selectableNumbers: selectable,
    stats: stats,
    totalPredictions: totalPredictions,
    mostPopularNumbers: mostPopular,
    mostProfitableNumbers: mostProfitable,
  );
}
