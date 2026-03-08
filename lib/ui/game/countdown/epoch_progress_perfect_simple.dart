import 'package:dashed_circular_progress_bar/dashed_circular_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/services/epoch_clock_service.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

/// Displays the circular epoch progress ring with
/// slot-based progress (not time-based).
///
/// Intended to be placed INSIDE a larger Stack that already
/// provides stars + clouds backgrounds.
class EpochProgress extends StatefulWidget {
  const EpochProgress({
    super.key,
    this.size = 280,
    this.strokeWidth = 18,
    this.animate = true,
    this.showLabel = true,
  });

  /// Overall ring size (width & height).
  final double size;

  /// Thickness of the foreground/background ring.
  final double strokeWidth;

  /// Whether the progress ring animates when values change.
  final bool animate;

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

  @override
  void dispose() {
    _valueNotifier.dispose();
    super.dispose();
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

    /// Selector ensures this widget rebuilds on EpochClockService ticks.
    ///
    /// IMPORTANT:
    /// This will only be "smooth" if EpochClockState provides estimatedSlotIndexNow
    /// and EpochClockService notifies on a fast tick interval (e.g. 1s).
    return Selector<EpochClockService, _EpochStats>(
      selector: (_, s) {
        final st = s.state;

        // Use ESTIMATED values so it changes every tick smoothly.
        // (Requires the getters we added to EpochClockState.)
        final slotIndex = st?.estimatedSlotIndexNow ?? 0;
        final slotsInEpoch = st?.slotsInEpoch ?? 0;
        final slotsLeft = st?.estimatedSlotsRemainingNow ?? 0;
        final etaSeconds = st?.estimatedTimeRemaining.inSeconds ?? 0;

        return _EpochStats(
          slotIndex: slotIndex,
          slotsInEpoch: slotsInEpoch,
          slotsLeft: slotsLeft,
          etaSeconds: etaSeconds,
        );
      },
      builder: (context, stats, _) {
        _syncRing(stats.slotIndex, stats.slotsInEpoch);

        final hasEpoch = stats.slotsInEpoch > 0;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: DashedCircularProgressBar.aspectRatio(
            aspectRatio: 1,

            /// Animation driver
            valueNotifier: _valueNotifier,

            /// Ring is percentage-based (0..100)
            progress: _valueNotifier.value,
            maxProgress: 100,

            /// Square dash ends for a crisp, mechanical look
            corners: StrokeCap.butt,

            /// Visual styling — tuned to match web app
            foregroundColor: AppColors.green,
            backgroundColor: Colors.white.withOpacityCompat(0.12),

            /// Ring thickness
            foregroundStrokeWidth: widget.strokeWidth,
            backgroundStrokeWidth: widget.strokeWidth,

            /// Animate when progress changes
            animation: widget.animate,

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
                          color: Colors.white.withOpacityCompat(0.70),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    /// (1) Thousands comma formatting here:
                    Text(
                      hasEpoch ? _comma.format(stats.slotsLeft) : '—',
                      style: t.displaySmall?.copyWith(fontWeight: FontWeight.w900, height: 1.0),
                    ),

                    const SizedBox(height: 10),

                    /// (3) ETA text instead of "slots completed"
                    Text(
                      hasEpoch ? 'ETA ${_formatEtaSeconds(stats.etaSeconds)}' : 'Syncing…',
                      style: t.titleSmall?.copyWith(
                        color: Colors.white.withOpacityCompat(0.78),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lightweight immutable snapshot used by Selector
/// to prevent unnecessary rebuilds.
class _EpochStats {
  const _EpochStats({
    required this.slotIndex,
    required this.slotsInEpoch,
    required this.slotsLeft,
    required this.etaSeconds,
  });

  final int slotIndex;
  final int slotsInEpoch;
  final int slotsLeft;
  final int etaSeconds;

  @override
  bool operator ==(Object other) =>
      other is _EpochStats &&
      other.slotIndex == slotIndex &&
      other.slotsInEpoch == slotsInEpoch &&
      other.slotsLeft == slotsLeft &&
      other.etaSeconds == etaSeconds;

  @override
  int get hashCode => Object.hash(slotIndex, slotsInEpoch, slotsLeft, etaSeconds);
}
