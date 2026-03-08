import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/models/profile/profile_vm_from_pda_mapper.dart';
import 'package:iseefortune_flutter/providers/bet_cutoff_provider.dart';
import 'package:iseefortune_flutter/providers/game_history_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_pda_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_stats_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/ui/history/game_history.dart';
import 'package:iseefortune_flutter/ui/how_to_play/how_to_play.dart';
import 'package:iseefortune_flutter/ui/profile/profile_modal.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/overhang_header.dart';
import 'package:iseefortune_flutter/ui/shared/app_background.dart';
import 'package:iseefortune_flutter/ui/shared/countdown_bet_cutoff.dart';
import 'package:iseefortune_flutter/ui/shared/cosmic_modal_shell.dart';
import 'package:iseefortune_flutter/ui/shared/glass_app_bar.dart';
import 'package:iseefortune_flutter/ui/shared/left_menu_drawer.dart';
import 'package:iseefortune_flutter/ui/shell/bottom_dock.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/epoch_display.dart';
import 'package:iseefortune_flutter/utils/profile/rank.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/main.dart' show routeObserver;
import 'package:iseefortune_flutter/providers/predictions_provider.dart';
import 'package:iseefortune_flutter/ui/game/countdown/game.dart';
import 'package:iseefortune_flutter/ui/shared/perserve_state.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/ui/shared/connect_wallet_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static RootShellState? of(BuildContext context) => context.findAncestorStateOfType<RootShellState>();

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> with RouteAware {
  int _index = 0;
  bool _shellActive = true; // RouteAware: only show when this page is active
  VoidCallback? _betCutoffListener;
  BetCutoffProvider? _betCutoffProvider;
  PageRoute? _subscribedRoute;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _pages = <Widget>[PreserveState(child: GamePage()), PreserveState(child: GameHistoryPage())];

  bool _predictionsStarted = false;

  @override
  void initState() {
    super.initState();

    // After first frame: start background fetch without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GameHistoryProvider>().start();
    });
  }

  @override
  void didPush() {
    _shellActive = true;
  }

  @override
  void didPopNext() {
    _shellActive = true;
  }

  @override
  void didPushNext() {
    _shellActive = false;
  }

  @override
  void didPop() {
    _shellActive = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      _subscribedRoute = route;
      routeObserver.subscribe(this, route);
    }

    _betCutoffListener ??= () {
      if (!mounted) return;
      if (!_shellActive) return;

      final p = _betCutoffProvider; // use the stored one
      if (p == null) return;
      if (!p.consumeJustClosed()) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.black.withOpacityCompat(0.85),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: AppColors.goldColor.withOpacityCompat(0.9), size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text('Bets closed for this epoch')),
              ],
            ),
          ),
        );
      });
    };

    final p = context.read<BetCutoffProvider>();
    if (_betCutoffProvider != p) {
      // detach from old (paranoia-safe)
      _betCutoffProvider?.removeListener(_betCutoffListener!);

      _betCutoffProvider = p;
      _betCutoffProvider!.addListener(_betCutoffListener!);
    }

    if (!_predictionsStarted) {
      _predictionsStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PredictionsProvider>().start();
      });
    }
  }

  @override
  void dispose() {
    final l = _betCutoffListener;
    if (l != null) {
      _betCutoffProvider?.removeListener(l);
    }
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _goTab(int i) => setState(() => _index = i);

  Future<void> _openProfileOrConnect() async {
    final conn = context.read<WalletConnectionProvider>();

    if (conn.isConnecting) return;

    if (!conn.isConnected) {
      showConnectWalletSheet(context);
      return;
    }

    final walletPubkey = conn.pubkey!;
    const hueDeg = 210;

    // NOTE: We wrap the entire sheet so we only build the VM once per rebuild.
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacityCompat(0.55),
      builder: (_) {
        return Consumer<ProfilePdaProvider>(
          builder: (context, pdaProv, _) {
            final pda = pdaProv.profile;

            if (pda == null) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }

            final vm = buildProfileVMFromPDA(walletPubkey: walletPubkey, pda: pda);

            final stats = context.watch<ProfileStatsProvider>().getCached(vm.handle);
            final loading = context.select<ProfileStatsProvider, bool>((p) => p.isLoading(vm.handle));

            final totalCorrect = stats?.totalWins ?? 0;
            final totalWrong = stats?.totalLosses ?? 0;
            final totalGames = totalCorrect + totalWrong;
            final bestWinStreak = stats?.bestWinStreak ?? 0;

            final rankLabel = getPlayerRankFromStats(
              totalCorrect: totalCorrect,
              totalWrong: totalWrong,
              totalGames: totalGames,
              bestWinStreak: bestWinStreak,
            );
            final subtitle = loading ? 'Updating…' : rankLabel;

            // Kick a refresh once the handle exists.
            // microtask avoids doing provider work directly during build.
            final handle = vm.handle.trim();
            if (handle.isNotEmpty && handle != '—') {
              Future.microtask(() {
                if (!context.mounted) return;
                context.read<ProfileStatsProvider>().refresh(handle);
              });
            }

            return CosmicModalShell(
              title: 'PROFILE',
              hueDeg: hueDeg,
              overhangLift: 76,
              overhang: ProfileOverhangHeader(
                handle: vm.handle,
                subtitle: subtitle,
                accent: vm.pal.pkColor,
                onClose: () => Navigator.of(context).pop(),
              ),
              showClouds: true,
              showStars: true,
              showHands: true,
              child: ProfileModal(vm: vm, isSelf: true, handle: vm.handle),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        key: _scaffoldKey,
        drawer: LeftMenuDrawer(
          onGoGame: () => _goTab(0),
          onGoHistory: () => _goTab(1), // or whichever index is your history page now
          onHowToPlay: () => HowToPlayModal.show(context),
          onWallet: () => showConnectWalletSheet(context),
          onProfile: () => _openProfileOrConnect(), // whatever your function is
          onOpenVerifier: () =>
              launchUrl(Uri.parse('https://verify.iseefortune.com'), mode: LaunchMode.externalApplication),

          onOpenDocs: () =>
              launchUrl(Uri.parse('https://docs.iseefortune.com'), mode: LaunchMode.externalApplication),
        ),
        drawerEdgeDragWidth: 28, // feels nice (optional)
        drawerEnableOpenDragGesture: false,
        // IMPORTANT: standard footer takes space, so don't extend body.
        extendBody: false,
        extendBodyBehindAppBar: true,

        appBar: GlassAppBar(
          // elevation: 0,
          // backgroundColor: Colors.transparent,
          // systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu_rounded, color: Colors.white38),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Builder(
            builder: (context) {
              final firstEpochInChain = context.select<LiveFeedProvider, BigInt?>(
                (p) => p.liveFeed?.firstEpochInChain,
              );
              final epoch = context.select<LiveFeedProvider, BigInt?>((p) => p.liveFeed?.epoch);

              final epochTitle = (firstEpochInChain == null || epoch == null)
                  ? 'GAME —'
                  : 'GAME ${formatEpochDisplay(firstEpochInChain: firstEpochInChain, epoch: epoch)}';

              final subtitleStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacityCompat(0.72),
              );

              return SizedBox(
                height: 35, // keeps it stable
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(epochTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    BetCutoffText(compact: true, style: subtitleStyle),
                  ],
                ),
              );
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Connect Wallet',
              icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white38),
              onPressed: () => showConnectWalletSheet(context),
            ),
          ],
        ),

        body: IndexedStack(
          index: _index,
          children: List.generate(_pages.length, (i) {
            final isActive = i == _index;

            return IgnorePointer(
              ignoring: !isActive, // prevents taps on hidden pages
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                opacity: isActive ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: isActive ? Offset.zero : const Offset(0, 0.04), // bottom-up only
                  child: _pages[i],
                ),
              ),
            );
          }),
        ),

        bottomNavigationBar: BottomDock(
          index: _index,
          onTab: (i) async {
            HapticFeedback.selectionClick();

            if (i == 2) {
              await _openProfileOrConnect();
              return; // IMPORTANT: do not switch tabs
            }

            _goTab(i);
          },
        ),
      ),
    );
  }
}
