import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game/countdown/pager_dots.dart';
import 'package:iseefortune_flutter/ui/game/countdown/game_header.dart';
import 'package:iseefortune_flutter/ui/game/screens/countdown.dart';
import 'package:iseefortune_flutter/ui/game/screens/predictions.dart';
import 'package:iseefortune_flutter/ui/game/screens/number_stats.dart';
import 'package:iseefortune_flutter/ui/shared/clouds.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // This drives the dashed progress widget.
  final ValueNotifier<double> _ringValue = ValueNotifier<double>(0);

  final PageController _page = PageController();

  @override
  void dispose() {
    _ringValue.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // RootShell has an AppBar; we only want SafeArea to handle left/right/bottom,
      // and let the header sit naturally under the app bar.
      top: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header bar (no ListView padding affecting it)
          const PotAndPlayersHeader(),

          // Body fills the remaining screen
          Expanded(
            child: CornerClouds(
              size: 94,
              padding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView(
                    controller: _page,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    pageSnapping: true,
                    children: [
                      CountdownPage(ringValue: _ringValue),
                      const NumberStatsPage(),
                      const PredictionsPage(),
                    ],
                  ),

                  // Bottom overlay: dots + bet box
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), // 14 + 10
                      child: PagerDots(controller: _page, count: 3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
