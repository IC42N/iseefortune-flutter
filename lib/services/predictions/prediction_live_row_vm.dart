import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediction_row_core_vm.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

enum LivePredictionStatus { inProgress, locked, unknown }

class LivePredictionRowVM {
  LivePredictionRowVM({required this.core, required this.status});

  final PredictionRowCore core;
  final LivePredictionStatus status;

  String get statusText {
    switch (status) {
      case LivePredictionStatus.inProgress:
        return 'IN PROGRESS';
      case LivePredictionStatus.locked:
        return 'LOCKED';
      case LivePredictionStatus.unknown:
        return '—';
    }
  }

  Color get statusColor {
    switch (status) {
      case LivePredictionStatus.inProgress:
        return AppColors.goldColor;
      case LivePredictionStatus.locked:
        return Colors.white70;
      case LivePredictionStatus.unknown:
        return Colors.white60;
    }
  }
}
