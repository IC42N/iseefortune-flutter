import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/game_resolution/game_resolution_debug_screen.dart';
import 'package:iseefortune_flutter/ui/shared/ball_icon.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class LeftMenuDrawer extends StatelessWidget {
  const LeftMenuDrawer({
    super.key,
    required this.onGoGame,
    required this.onGoHistory,
    this.onWallet,
    this.onHowToPlay,
    this.onProfile,
    this.onOpenVerifier,
    this.onOpenDocs,
  });

  final VoidCallback onGoGame;
  final VoidCallback onGoHistory;

  final VoidCallback? onWallet;
  final VoidCallback? onHowToPlay;
  final VoidCallback? onProfile;
  final VoidCallback? onOpenVerifier;
  final VoidCallback? onOpenDocs;

  @override
  Widget build(BuildContext context) {
    void closeThen(VoidCallback? action) {
      Navigator.of(context).pop(); // close drawer
      if (action == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF101C2E).withOpacityCompat(0.35),
              border: Border(right: BorderSide(color: Colors.white.withOpacityCompat(0.08))),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                children: [
                  const SizedBox(height: 6),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacityCompat(0.20),
                          border: Border.all(color: Colors.white.withOpacityCompat(0.12)),
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(2), // controls icon size
                            child: Image.asset('assets/icon/eye-logo.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I See Fortune',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Epoch Game of the Future',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // In-game
                  _MenuItem(
                    iconWidget: svgBall(size: 20, color: Colors.white70),
                    title: 'Play Game',
                    subtitle: 'Play and pick numbers',
                    onTap: () => closeThen(onGoGame),
                  ),
                  _MenuItem(
                    icon: Icons.history_rounded,
                    title: 'Game History',
                    subtitle: 'Past epochs + results',
                    onTap: () => closeThen(onGoHistory),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    title: 'How to Play',
                    subtitle: 'Quick guide',
                    onTap: () => closeThen(onHowToPlay),
                  ),

                  const SizedBox(height: 8),
                  Divider(color: Colors.white.withOpacityCompat(0.05)),
                  const SizedBox(height: 8),

                  // External + account
                  _MenuItem(
                    icon: Icons.verified_rounded,
                    title: 'Verifier',
                    subtitle: 'Verify results publicly',
                    onTap: () => closeThen(onOpenVerifier),
                  ),

                  _MenuItem(
                    icon: Icons.menu_book_rounded,
                    title: 'Documentation',
                    subtitle: 'Learn how the system works',
                    onTap: () => closeThen(onOpenDocs),
                  ),
                  _MenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet',
                    subtitle: 'Connect / manage',
                    onTap: () => closeThen(onWallet),
                  ),
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'Your predictions + claims',
                    onTap: () => closeThen(onProfile),
                  ),

                  // DEBUG GAME ENDING ANIMATION
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Divider(color: Colors.white.withOpacityCompat(0.05)),
                    const SizedBox(height: 8),
                    _MenuItem(
                      icon: Icons.bug_report_rounded,
                      title: 'Debug: Resolution Modal',
                      subtitle: 'Test win/loss/rollover flows',
                      onTap: () => closeThen(() {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const GameResolutionDebugScreen()));
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null, 'Provide either icon or iconWidget'),
       assert(!(icon != null && iconWidget != null), 'Provide only one of icon or iconWidget');

  final IconData? icon; // for Material icons
  final Widget? iconWidget; // for SVG or custom widgets
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final innerIcon = iconWidget ?? Icon(icon, size: 20);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacityCompat(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacityCompat(0.08),
                ),
                child: IconTheme(
                  data: IconThemeData(color: Colors.white.withOpacityCompat(0.75), size: 20),
                  child: innerIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),

                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacityCompat(0.65)),
            ],
          ),
        ),
      ),
    );
  }
}
