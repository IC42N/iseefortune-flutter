// lib/services/live_feed/live_feed_vm_stream.dart

import 'package:iseefortune_flutter/services/config_service.dart';
import 'package:iseefortune_flutter/services/live_feed_service.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_builder.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';

class LiveFeedVmStreamService {
  LiveFeedVmStreamService({required LiveFeedService liveFeedService, required ConfigService configService})
    : _liveFeed = liveFeedService,
      _config = configService;

  final LiveFeedService _liveFeed;
  final ConfigService _config;

  Stream<LiveFeedVM> subscribeVmForTierLivePrimary(
    int tier, {
    String liveFeedCommitment = 'confirmed',
    String configCommitment = 'confirmed',
  }) async* {
    final config$ = await _config.subscribeConfig(commitment: configCommitment);
    yield* config$.asyncExpand((cfg) {
      final primary = cfg.primaryRollOverNumber;
      return _liveFeed
          .subscribeLiveFeed(tier, commitment: liveFeedCommitment)
          .map((lf) => buildLiveFeedVM(liveFeed: lf, primaryRollOverNumber: primary));
    });
  }
}
