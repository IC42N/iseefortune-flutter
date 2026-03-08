import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/services/predictions/prediction_live_row_vm.dart';
import 'package:iseefortune_flutter/ui/shared/selected_numbers.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

class PredictionRow extends StatelessWidget {
  const PredictionRow({super.key, required this.vm, required this.isTop});

  final LivePredictionRowVM vm;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    // Primary pick drives the hue (same idea as CSS --hue).
    final hue = hueForNumber(vm.core.primary);
    final pal = RowHuePalette(hue);

    final tintStrong = pal.tintStrong;
    final tintSoft = pal.tintSoft;
    final railTop = pal.railTop;
    final railBottom = pal.railBottom;
    final pkColor = pal.pkColor;

    // Amount split line like web: main + sub.
    final totalAmountSol = lamportsToSolTrim(vm.core.totalLamports);
    final perNumberSol = lamportsToSolTrim(vm.core.lamportsPerPick);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4), // web had 4px; 10 looks nicer in mobile
      child: Stack(
        children: [
          // ------------------------------------------------------------
          // Base surface: background + border + subtle inset highlight
          // (matches: background rgba(0,0,0,0.25), border, inset stroke)
          // ------------------------------------------------------------
          // Container(
          //   decoration: BoxDecoration(
          //     color: Colors.black.withOpacityCompat(0.25),
          //     border: Border.all(color: Colors.black.withOpacityCompat(0.07)),
          //     boxShadow: [
          //       // inset-ish highlight: use a normal shadow with negative spread
          //       BoxShadow(color: Colors.white.withOpacityCompat(0.03), blurRadius: 0, spreadRadius: -1),
          //     ],
          //   ),
          // ),

          // ------------------------------------------------------------
          // Tint overlay (matches ::after)
          // ------------------------------------------------------------
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      tintStrong,
                      tintSoft,
                      // a little “mystery” at the end
                      HSLColor.fromAHSL(0.10, hue, 0.95, 0.55).toColor(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ------------------------------------------------------------
          // Left rail (matches ::before) — 1px with glow
          // ------------------------------------------------------------
          Positioned(
            left: 1,
            top: 1,
            bottom: 1,
            child: IgnorePointer(
              child: Container(
                width: 1.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [railTop, railBottom],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HSLColor.fromAHSL(0.22, hue, 0.95, 0.60).toColor(),
                      blurRadius: 18,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ------------------------------------------------------------
          // Content layer (z-index: 1)
          // ------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 5),
            child: Row(
              children: [
                // PLAYER (matches .player + .pk)
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      // optional little dot/icon if you want later
                      // Container(width: 6, height: 6, decoration: BoxDecoration(...)),
                      Flexible(
                        child: Text(
                          vm.core.playerLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: pkColor, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  flex: 4,
                  child: SelectedNumbers(
                    numbers: vm.core.picks,
                    size: 26,
                    opacity: 0.85,
                    align: Alignment.centerRight,
                    spacing: 3,
                    runSpacing: 3,
                  ),
                ),

                //const SizedBox(width: 10),

                // AMOUNT (matches .amount + .amountSub)
                SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TOTAL SOL (primary)
                      Text(
                        '$totalAmountSol SOL', // e.g. "2.50 SOL"
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          //color: Colors.white.withOpacityCompat(0.70),
                          color: pkColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [Shadow(blurRadius: 10, color: Colors.white.withOpacityCompat(0.10))],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // PER-PICK SOL (secondary)
                      Text(
                        '$perNumberSol ea', // or "0.50 SOL ea"
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.5, // ⬇️ smaller
                          height: 1.0,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacityCompat(0.55),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
