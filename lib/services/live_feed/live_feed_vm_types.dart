import 'package:flutter/material.dart';

class NumberStatVM {
  const NumberStatVM({
    required this.number, // 1..9
    required this.count, // betsPerNumber[number]
    required this.percent, // 0..100 among selectable
    required this.color,
    required this.isPopular,
    required this.lamportsPerNumber, // raw payout info
  });

  final int number;
  final int count;
  final double percent;
  final Color color;
  final bool isPopular;
  final BigInt lamportsPerNumber;
}

class LiveFeedVM {
  LiveFeedVM({
    required this.selectableNumbers,
    required this.stats,
    required this.totalPredictions,
    required this.mostPopularNumbers,
    required this.mostProfitableNumbers,
  });

  final List<int> selectableNumbers;
  final List<NumberStatVM> stats;
  final int totalPredictions;

  /// Max predictions (ties allowed, but capped to <=4 or empty if too many)
  final List<int> mostPopularNumbers;

  /// Min predictions (ties allowed, but capped to <=4 or empty if too many)
  final List<int> mostProfitableNumbers;
}
