import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/config_model.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/providers/predictions_provider.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/ui/shared/animated_lamports_text.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/tiers.dart';
import 'package:provider/provider.dart';

/// Glass header: Tier (left) + Pot (center) + Players (right)
class PotAndPlayersHeader extends StatelessWidget {
  const PotAndPlayersHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final potLamports = context.select<LiveFeedProvider, BigInt?>((p) => p.liveFeed?.totalLamports);
    final playersPlaying = context.select<PredictionsProvider, int>((p) => p.streamedPredictionCount);

    final config = context.select<ConfigProvider, ConfigModel?>((p) => p.config);
    final tierId = context.select<TierProvider, int?>((p) => p.isReady ? p.tier : null);

    final tierSettings = (config != null && tierId != null) ? config.tier(tierId) : null;

    final tierLabel = tierId == null ? '—' : 'TIER $tierId';
    final rangeText = tierBetRangeText(tierSettings);
    final playersText = playersPlaying > 0 ? playersPlaying.toString() : '0';

    final valueStyle = t.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.0,
      fontSize: 14,
    );

    final potStyle = t.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.0,
      fontSize: 18,
    );

    final labelStyle = t.labelMedium?.copyWith(
      color: Colors.white.withOpacityCompat(0.50),
      fontSize: 9,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
    );

    return _GlassCard(
      child: LayoutBuilder(
        builder: (context, c) {
          final baseH = 44.0; // height of the left/right bar - 52
          final potH = 47.0; // height of the center pot tab - 66
          final protrude = potH - baseH; // how much it hangs down
          final slant = 14.0; // inward slant amount for the dividers

          final centerFrac = 0.42; // try 0.38–0.44

          final dpr = MediaQuery.of(context).devicePixelRatio;
          double snap(double x) => (x * dpr).round() / dpr;

          final centerW = snap(c.maxWidth * centerFrac);
          final sideW = snap((c.maxWidth - centerW) / 2);

          final ghostInset = snap((centerW * 0.04).clamp(8.0, 16.0));
          final ghostW = snap((centerW - ghostInset * 2).clamp(0.0, centerW));
          final ghostLeft = snap(sideW + (centerW - ghostW) / 2); // no nudge

          final bg = const Color.fromARGB(255, 10, 15, 26);
          final sideBg = const Color.fromARGB(255, 16, 22, 34); // slightly darker
          final potBg = const Color.fromARGB(255, 14, 22, 40); // highlighted center

          return SizedBox(
            height: potH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // BASE BAR (left + right), slightly darker than center
                Positioned.fill(
                  top: 0,
                  bottom: protrude,
                  child: Container(
                    color: bg,
                    child: Row(
                      children: [
                        SizedBox(
                          width: sideW,
                          child: Container(
                            color: sideBg,
                            padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tierLabel, style: labelStyle),
                                const SizedBox(height: 3),
                                Text(rangeText, style: valueStyle),
                              ],
                            ),
                          ),
                        ),

                        Container(width: centerW, color: sideBg),

                        SizedBox(
                          width: sideW,
                          child: Container(
                            color: sideBg,
                            padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('PREDICTIONS', style: labelStyle),
                                const SizedBox(height: 3),
                                Text(playersText, style: valueStyle),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // CENTER POT TAB (protrudes down)
                Positioned(
                  top: 0,
                  left: sideW,
                  width: centerW,
                  height: potH,
                  child: ClipPath(
                    clipper: _PotTrapezoidClipper(slant: slant),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: potBg,
                        border: Border(
                          left: BorderSide(color: Colors.white.withOpacityCompat(0.10), width: 1),
                          right: BorderSide(color: Colors.white.withOpacityCompat(0.10), width: 1),
                          bottom: BorderSide(
                            color: const Color.fromARGB(255, 0, 0, 0).withOpacityCompat(0.14),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('CURRENT POT', style: labelStyle),
                            const SizedBox(height: 4),
                            AnimatedLamportsSolText(lamports: potLamports, textStyle: potStyle!),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Optional: subtle highlight “shine” on the pot tab
                Positioned(
                  top: 0,
                  left: ghostLeft,
                  width: ghostW,
                  height: potH,
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: _PotTrapezoidClipper(slant: slant),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withOpacityCompat(0.10), Colors.transparent],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 0,
                  left: sideW,
                  width: centerW,
                  height: potH,
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: _PotTrapezoidClipper(slant: slant),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withOpacityCompat(0.10), Colors.transparent],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // TOP highlight border (subtle)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white.withOpacityCompat(0.08), // tweak 0.05–0.12
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withOpacityCompat(0.22)),
          child: child,
        ),
      ),
    );
  }
}

class _PotTrapezoidClipper extends CustomClipper<Path> {
  _PotTrapezoidClipper({required this.slant});
  final double slant;

  @override
  Path getClip(Size size) {
    // Trapezoid: top wider, bottom narrower (inward slants)
    final s = slant.clamp(0.0, size.width * 0.25);

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - s, size.height)
      ..lineTo(s, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _PotTrapezoidClipper oldClipper) => oldClipper.slant != slant;
}
