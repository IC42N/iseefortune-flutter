import 'package:flutter/foundation.dart';

@immutable
class ClaimParams {
  const ClaimParams({required this.predictionPda});

  final String predictionPda;

  /// Provider key (we key claim state by PDA everywhere)
  String get key => predictionPda;
}
