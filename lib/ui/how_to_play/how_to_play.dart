import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/how_to_play/footer.dart';
import 'package:iseefortune_flutter/ui/how_to_play/sections/game_mechanics.dart';
import 'package:iseefortune_flutter/ui/how_to_play/sections/how_to_play.dart';
import 'package:iseefortune_flutter/ui/how_to_play/sections/overview.dart';
import 'package:iseefortune_flutter/ui/how_to_play/sections/verifiable.dart';
import 'package:iseefortune_flutter/ui/how_to_play/widgets/dismiss_button.dart';
import 'package:iseefortune_flutter/ui/how_to_play/widgets/slogan.dart';
import 'package:iseefortune_flutter/ui/shared/cosmic_modal_shell.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

enum HowToPlayTab { overview, howToPlay, mechanics, verifiable }

extension on HowToPlayTab {
  String get label => switch (this) {
    HowToPlayTab.overview => 'Overview',
    HowToPlayTab.howToPlay => 'How to Play',
    HowToPlayTab.mechanics => 'Mechanics',
    HowToPlayTab.verifiable => 'Verify',
  };
}

class HowToPlayModal extends StatefulWidget {
  const HowToPlayModal({super.key, this.initialTab = HowToPlayTab.overview});
  final HowToPlayTab initialTab;

  static Future<void> show(BuildContext context, {HowToPlayTab initialTab = HowToPlayTab.overview}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: HowToPlayModal(initialTab: initialTab),
      ),
    );
  }

  @override
  State<HowToPlayModal> createState() => _HowToPlayModalState();
}

class _HowToPlayModalState extends State<HowToPlayModal> {
  late HowToPlayTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return CosmicModalShell(
      title: 'How to Play',
      subtitle: null,
      overhangLift: 0,
      showStars: true,
      showHands: false,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min, // <-- IMPORTANT
              children: [
                const SizedBox(height: 50),

                _TabsRow(active: _tab, onSelect: (t) => setState(() => _tab = t)),
                const SizedBox(height: 24),

                // Fade panel (remount on tab change)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: _TabPanel(tab: _tab),
                ),

                const SizedBox(height: 10),
                const Slogan(),
                const SizedBox(height: 3),
                const Footer(),
                const SizedBox(height: 14),
              ],
            ),
          ),

          const Positioned(top: 15, right: 15, child: DismissButton()),
        ],
      ),
    );
  }
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.active, required this.onSelect});
  final HowToPlayTab active;
  final ValueChanged<HowToPlayTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final t in HowToPlayTab.values)
              _TabPill(label: t.label, isActive: t == active, onTap: () => onSelect(t)),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? Colors.black : Colors.white.withOpacityCompat(0.78);
    final bg = isActive ? AppColors.goldColor : Colors.white.withOpacityCompat(0.06);
    final border = isActive ? Colors.transparent : Colors.white.withOpacityCompat(0.10);

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _TabPanel extends StatelessWidget {
  const _TabPanel({required this.tab});
  final HowToPlayTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      HowToPlayTab.overview => const OverviewSection(),
      HowToPlayTab.howToPlay => const HowToPlaySection(),
      HowToPlayTab.mechanics => const GameRulesSection(),
      HowToPlayTab.verifiable => const VerifiableSection(),
    };
  }
}
