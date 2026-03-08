import 'dart:async';

import 'package:dashed_circular_progress_bar/dashed_circular_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iseefortune_flutter/models/game_resolution/game_resolution_model.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_predictions_provider.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/solana/pdas.dart';
import 'package:iseefortune_flutter/ui/game/countdown/epoch_glow_layer.dart';
import 'package:iseefortune_flutter/ui/game/countdown/epoch_stats.dart';
import 'package:iseefortune_flutter/ui/game/countdown/helpers.dart';
import 'package:iseefortune_flutter/ui/game_resolution/game_resolution_modal.dart';
import 'package:iseefortune_flutter/ui/game_resolution/resolution_anchor.dart';
import 'package:iseefortune_flutter/utils/numbers/numbers.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/services/epoch_clock_service.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:solana/solana.dart';

/// Displays the circular epoch progress ring with
/// slot-based progress (not time-based).
///
/// Intended to be placed INSIDE a larger Stack that already
/// provides stars + clouds backgrounds.
class EpochProgress extends StatefulWidget {
  const EpochProgress({super.key, this.size = 280, this.strokeWidth = 18, this.showLabel = true});

  /// Overall ring size (width & height).
  final double size;

  /// Thickness of the foreground/background ring.
  final double strokeWidth;

  /// Shows "SLOTS LEFT" label above the main number.
  final bool showLabel;

  @override
  State<EpochProgress> createState() => _EpochProgressState();
}

class _EpochProgressState extends State<EpochProgress> {
  /// Drives the dashed progress bar animation.
  ///
  /// Value is expressed as 0..100 (percentage),
  /// even though the actual source data is slot-based.
  final ValueNotifier<double> _valueNotifier = ValueNotifier<double>(0);

  /// Thousands separator formatter: 12345 -> 12,345
  final NumberFormat _comma = NumberFormat.decimalPattern();

  // Only animate the ring once (shared across remounts)
  static bool _didAnimateOnce = false;

  bool get _shouldAnimate => !_didAnimateOnce;

  ResolutionAnchor? _anchor;
  int? _lastEtaSeconds;
  int? _openedForEpoch;
  int? _lastAnchorEpoch;
  int? _lastAnchorTier;
  bool _derivingPda = false;

  void _markAnimatedOnce() {
    if (!_didAnimateOnce) _didAnimateOnce = true;
  }

  @override
  void dispose() {
    _valueNotifier.dispose();
    super.dispose();
  }

  Future<void> _ensureAnchorPda({required int secondsLeft, required int epochInt, required int tier}) async {
    if (!mounted) return;
    if (secondsLeft <= 0) return; // freeze at 0

    // Only re-derive if epoch/tier actually changed
    if (_lastAnchorEpoch == epochInt && _lastAnchorTier == tier) return;
    if (_derivingPda) return;

    _derivingPda = true;
    _lastAnchorEpoch = epochInt;
    _lastAnchorTier = tier;

    try {
      final pda = await AppPdas.resolvedGamePdaPubkey(epoch: epochInt, tier: tier);
      if (!mounted) return;

      _maybeUpdateAnchor(
        secondsLeft: secondsLeft,
        epochFromLiveFeed: epochInt,
        tier: tier,
        resolvedGamePda: pda,
      );
    } finally {
      _derivingPda = false;
    }
  }

  void _maybeUpdateAnchor({
    required int secondsLeft,
    required int epochFromLiveFeed,
    required int tier,
    required Ed25519HDPublicKey resolvedGamePda,
  }) {
    // Only maintain the anchor while the countdown is active.
    // Once we hit 0, we freeze it (so the modal is anchored to the ended game).
    if (secondsLeft <= 0) return;

    final next = ResolutionAnchor(epoch: epochFromLiveFeed, tier: tier, resolvedGamePda: resolvedGamePda);

    if (_anchor != next) {
      _anchor = next;
    }
  }

  bool _crossedToZero(int secondsLeft) {
    final prev = _lastEtaSeconds;
    _lastEtaSeconds = secondsLeft;

    if (prev == null) return false; // first frame: don’t trigger
    return prev > 0 && secondsLeft == 0;
  }

  /// Syncs the circular ring to the current epoch slot progress.
  ///
  /// Converts:
  ///   slotIndex / slotsInEpoch  →  0..100%
  void _syncRing(int slotIndex, int slotsInEpoch) {
    if (slotsInEpoch <= 0) {
      _valueNotifier.value = 0;
      return;
    }

    final current = slotIndex.clamp(0, slotsInEpoch);
    final pct = (current / slotsInEpoch) * 100.0;

    // Prevent unnecessary notifier updates (micro-optimisation)
    if ((_valueNotifier.value - pct).abs() > 0.001) {
      _valueNotifier.value = pct;
    }
  }

  /// Formats ETA like:
  /// - mm:ss for under 1 hour
  /// - h:mm:ss for 1 hour+
  String _formatEtaSeconds(int seconds) {
    if (seconds <= 0) return '—';

    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Selector<EpochClockService, EpochStats>(
      selector: (_, s) {
        final st = s.state;

        // Use ESTIMATED values so it changes every tick smoothly.
        // (Requires the getters we added to EpochClockState.)
        final slotIndex = st?.estimatedSlotIndexNow ?? 0;
        final slotsInEpoch = st?.slotsInEpoch ?? 0;
        final slotsLeft = st?.estimatedSlotsRemainingNow ?? 0;
        final etaSeconds = st?.estimatedTimeRemaining.inSeconds ?? 0;

        return EpochStats(
          slotIndex: slotIndex,
          slotsInEpoch: slotsInEpoch,
          slotsLeft: slotsLeft,
          etaSeconds: etaSeconds,
        );
      },
      builder: (context, stats, _) {
        _syncRing(stats.slotIndex, stats.slotsInEpoch);

        final hasEpoch = stats.slotsInEpoch > 0;
        final p01 = hasEpoch ? (stats.slotIndex / stats.slotsInEpoch).clamp(0.0, 1.0) : 0.0;
        final band = bandForProgress01(p01);

        // Providers (read once)
        final tier = context.read<TierProvider>().tier;
        final live = context.read<LiveFeedProvider>();
        final wallet = context.read<WalletProvider>();
        final preds = context.read<PlayerPredictionsProvider>();

        // -------------------------------
        // (A) Anchor epoch (for ResolvedGame PDA)
        // Use CURRENT epoch (not firstEpochInChain)
        // -------------------------------
        final anchorEpochRaw = live.liveFeed?.epoch ?? BigInt.zero;
        final anchorEpochInt = safeEpochToInt(anchorEpochRaw);

        if (anchorEpochInt > 0) {
          _ensureAnchorPda(secondsLeft: stats.etaSeconds, epochInt: anchorEpochInt, tier: tier);
        }

        // -------------------------------
        // (B) Trigger modal exactly once at cross to zero
        // -------------------------------
        final crossed = _crossedToZero(stats.etaSeconds);

        if (crossed && _anchor != null && _anchor!.epoch > 0 && _openedForEpoch != _anchor!.epoch) {
          _openedForEpoch = _anchor!.epoch;

          // -------------------------------
          // (C) Player context (did they play THIS GAME CHAIN?)
          // This uses firstEpochInChain because Prediction.gameEpoch == firstEpochInChain
          // -------------------------------
          final gameEpoch = live.liveFeed?.firstEpochInChain ?? BigInt.zero;

          final walletConnected = wallet.isConnected; // or: wallet.pubkey != null
          final predictionPda = preds.findPredictionPdaForGameEpoch(
            gameEpoch: gameEpoch,
            tier: tier,
            playerPubkey: wallet.pubkey, // optional safety
          );

          final playerPlayed = predictionPda != null;

          final args = GameResolutionModalArgs(
            anchorEpoch: _anchor!.epoch,
            resolvedGamePda: _anchor!.resolvedGamePda,
            walletConnected: walletConnected,
            playerPlayed: playerPlayed,
          );

          Future.microtask(() {
            GameResolutionModal.show(context, args: args);
          });
        }

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow BEHIND
              EpochGlowLayer(
                size: widget.size,
                color: band.color, // or your band color
                pulseMs: band.pulseMs,
                intensity: band.intensity, // 0..1 (you can map from progress)
              ),

              DashedCircularProgressBar.aspectRatio(
                aspectRatio: 1,

                /// Animation driver
                valueNotifier: _valueNotifier,

                /// Ring is percentage-based (0..100)
                progress: _valueNotifier.value,
                maxProgress: 100,

                /// Square dash ends for a crisp, mechanical look
                corners: StrokeCap.butt,

                /// Visual styling — tuned to match web app
                foregroundColor: band.color,
                backgroundColor: const Color.fromARGB(255, 40, 43, 51).withOpacityCompat(0.82),

                /// Ring thickness
                foregroundStrokeWidth: widget.strokeWidth,
                backgroundStrokeWidth: widget.strokeWidth,

                /// Animate when progress changes
                animation: _shouldAnimate,
                onAnimationEnd: _markAnimatedOnce,

                /// Center content: labels + slot numbers + ETA
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showLabel) ...[
                          Text(
                            'SLOTS LEFT',
                            style: t.labelMedium?.copyWith(
                              letterSpacing: 1.4,
                              fontSize: 16,
                              color: Colors.white.withOpacityCompat(0.70),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        /// (1) Thousands comma formatting here:
                        Text(
                          hasEpoch ? _comma.format(stats.slotsLeft) : '—',
                          style: t.displayLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                            fontSize: 54,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// (3) ETA text instead of "slots completed"
                        Text(
                          hasEpoch ? 'ETA ${_formatEtaSeconds(stats.etaSeconds)}' : 'Syncing…',
                          style: t.labelSmall?.copyWith(
                            color: Colors.white.withOpacityCompat(0.78),
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
