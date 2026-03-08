import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/api/claim.dart';
import 'package:iseefortune_flutter/providers/bet_cutoff_provider.dart';
import 'package:iseefortune_flutter/providers/claim/claim_provider.dart';
import 'package:iseefortune_flutter/providers/game/resolved_game_cache_provider.dart';
import 'package:iseefortune_flutter/providers/game_history_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_pda_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_predictions_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_stats_provider.dart';
import 'package:iseefortune_flutter/providers/game/resolved_game_panel_provider.dart';
import 'package:iseefortune_flutter/services/claim/claim_tx_service.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_chain_service.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_db_service.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_extras_service.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_repo.dart';
import 'package:iseefortune_flutter/services/history/history_api.dart';
import 'package:iseefortune_flutter/services/profile/player_predicitons_service.dart';
import 'package:iseefortune_flutter/services/profile/profile_pda_service.dart';
import 'package:iseefortune_flutter/solana/service/client.dart';
import 'package:iseefortune_flutter/solana/signing/tx_router.dart';
import 'package:iseefortune_flutter/solana/wallet/kotlin_mwa_client.dart';
import 'package:iseefortune_flutter/ui/game_resolution/game_resolution_debug_screen.dart';
import 'package:iseefortune_flutter/ui/shared/app_background.dart';
import 'package:iseefortune_flutter/ui/shell/shell.dart';
import 'package:iseefortune_flutter/ui/theme/themes.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/services/epoch_clock_service.dart';
import 'package:iseefortune_flutter/ui/loading/boot_screen.dart';

import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/price_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/solana/wallet_balance_stream.dart';

// Solana shared WebSocket
import 'package:iseefortune_flutter/solana/service/websocket.dart';

// Boot snapshot (getMultipleAccounts)
import 'package:iseefortune_flutter/services/boot_snapshot_service.dart';

// LiveFeed
import 'package:iseefortune_flutter/services/live_feed_service.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';

// Config
import 'package:iseefortune_flutter/services/config_service.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';

// Bets (background stream)
import 'package:iseefortune_flutter/providers/predictions_provider.dart';
import 'package:iseefortune_flutter/services/predictions_service.dart';

// Wallet adapter (MWA wrapper)
import 'package:iseefortune_flutter/solana/wallet/wallet_adapter_services.dart';
import 'package:solana_seed_vault/solana_seed_vault.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    MultiProvider(
      providers: [
        // -------------------------------------------------------------------
        // Theme provider
        // -------------------------------------------------------------------
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // -------------------------------------------------------------------
        // App services
        // -------------------------------------------------------------------
        ChangeNotifierProvider(create: (_) => EpochClockService()),
        ChangeNotifierProvider(create: (_) => TierProvider()),

        // -------------------------------------------------------------------
        // Solana RPC client (HTTP)
        // -------------------------------------------------------------------
        Provider<SolanaClientService>(create: (_) => SolanaClientService()),

        // -------------------------------------------------------------------
        // Solana WebSocket (single shared socket)
        // -------------------------------------------------------------------
        Provider<SolanaWsService>(
          create: (_) => SolanaWsService(pingInterval: const Duration(seconds: 20)),
          dispose: (_, ws) => ws.dispose(),
        ),

        // -------------------------------------------------------------------
        // Wallet Adapter Service (MWA)
        // -------------------------------------------------------------------
        Provider<KotlinMwaClient>(create: (_) => KotlinMwaClient()),

        Provider<SolanaWalletAdapterService>(
          create: (ctx) =>
              SolanaWalletAdapterService(cluster: 'mainnet-beta', client: ctx.read<KotlinMwaClient>()),
        ),

        // -------------------------------------------------------------------
        // Wallet connection (pubkey + auth token) – source of truth
        // MUST be above WalletProvider proxy
        // -------------------------------------------------------------------
        ChangeNotifierProvider<WalletConnectionProvider>(
          create: (ctx) => WalletConnectionProvider(mwa: ctx.read<SolanaWalletAdapterService>()),
        ),

        // -------------------------------------------------------------------
        // Wallet stack
        // -------------------------------------------------------------------
        ChangeNotifierProvider(create: (_) => PriceProvider()),
        ChangeNotifierProxyProvider2<WalletConnectionProvider, PriceProvider, WalletProvider>(
          create: (_) => WalletProvider(balanceStream: WalletBalanceStream()),
          update: (_, conn, price, wallet) {
            wallet!.attachWalletConnection(conn);
            wallet.attachPriceProvider(price);
            return wallet;
          },
        ),

        // -------------------------------------------------------------------
        // Profile PDA service
        // -------------------------------------------------------------------
        Provider<ProfilePdaService>(create: (ctx) => ProfilePdaService(ctx.read<SolanaWsService>())),

        // -------------------------------------------------------------------
        // Profile PDA
        // -------------------------------------------------------------------
        ChangeNotifierProxyProvider<WalletConnectionProvider, ProfilePdaProvider>(
          lazy: false,
          create: (ctx) => ProfilePdaProvider(service: ctx.read<ProfilePdaService>()),
          update: (ctx, wallet, profile) {
            profile ??= ProfilePdaProvider(service: ctx.read<ProfilePdaService>());
            profile.attachWalletConnection(wallet);
            return profile;
          },
        ),

        // -------------------------------------------------------------------
        // Boot snapshot (single HTTP call, optional optimization)
        // -------------------------------------------------------------------
        Provider<BootSnapshotService>(create: (_) => BootSnapshotService()),

        // -------------------------------------------------------------------
        // Config (global)
        // -------------------------------------------------------------------
        Provider<ConfigService>(create: (ctx) => ConfigService(ctx.read<SolanaWsService>())),
        ChangeNotifierProxyProvider<ConfigService, ConfigProvider>(
          create: (_) => ConfigProvider(enableSubscription: true),
          update: (_, service, provider) {
            provider ??= ConfigProvider(enableSubscription: true);
            provider.attachService(service);
            return provider;
          },
        ),

        // -------------------------------------------------------------------
        // LiveFeed (tier-driven)
        // -------------------------------------------------------------------
        Provider<LiveFeedService>(create: (ctx) => LiveFeedService(ctx.read<SolanaWsService>())),
        ChangeNotifierProxyProvider2<TierProvider, LiveFeedService, LiveFeedProvider>(
          create: (_) => LiveFeedProvider(),
          update: (_, tier, service, provider) {
            provider ??= LiveFeedProvider();
            provider.attachTier(tier);
            provider.attachService(service);
            return provider;
          },
        ),

        // -------------------------------------------------------------------
        // Bets (background stream)
        // -------------------------------------------------------------------
        Provider<PredictionsService>(
          create: (ctx) => PredictionsService(ctx.read<SolanaWsService>(), ctx.read<SolanaClientService>()),
        ),
        ChangeNotifierProxyProvider3<TierProvider, LiveFeedProvider, PredictionsService, PredictionsProvider>(
          create: (_) => PredictionsProvider(enableSubscription: true),
          update: (_, tier, live, service, provider) {
            provider ??= PredictionsProvider(enableSubscription: true);
            provider.attachTier(tier);
            provider.attachLiveFeed(live);
            provider.attachService(service);
            return provider;
          },
        ),

        ChangeNotifierProxyProvider2<ConfigProvider, EpochClockService, BetCutoffProvider>(
          create: (_) => BetCutoffProvider(),
          update: (_, config, clock, betCutoff) {
            betCutoff!.update(config: config, clock: clock);
            return betCutoff;
          },
        ),

        // Winning number history
        ChangeNotifierProvider(create: (_) => GameHistoryProvider(api: WinningHistoryApi())),

        // Resolved game (API + chain)
        Provider<ResolvedGameApiService>(create: (_) => ResolvedGameApiService()),
        // Resolved game chain service (stateless)
        Provider<ResolvedGameService>(create: (ctx) => ResolvedGameService(ctx.read<SolanaWsService>())),

        // Resolved game extras service (POST /resolved-game-extras)
        Provider<ResolvedGameExtrasApiService>(create: (_) => ResolvedGameExtrasApiService()),

        Provider<ResolvedGameRepository>(
          create: (ctx) => ResolvedGameRepository(
            api: ctx.read<ResolvedGameApiService>(),
            chain: ctx.read<ResolvedGameService>(),
            extrasApi: ctx.read<ResolvedGameExtrasApiService>(),
          ),
        ),

        ChangeNotifierProxyProvider<ResolvedGameRepository, ResolvedGameCacheProvider>(
          create: (ctx) => ResolvedGameCacheProvider(repo: ctx.read<ResolvedGameRepository>()),
          update: (ctx, repo, provider) {
            provider ??= ResolvedGameCacheProvider(repo: repo);
            provider.attachRepo(repo);
            return provider;
          },
        ),

        ChangeNotifierProxyProvider3<
          TierProvider,
          GameHistoryProvider,
          ResolvedGameRepository,
          ResolvedGamePanelProvider
        >(
          create: (ctx) => ResolvedGamePanelProvider(repo: ctx.read<ResolvedGameRepository>()),
          update: (ctx, tierProv, histProv, repo, provider) {
            provider ??= ResolvedGamePanelProvider(repo: repo);

            // If repo could ever change (hot reload, tests), reattach.
            provider.attachRepo(repo);

            // Push tier (provider will no-op if unchanged)
            provider.setTier(tierProv.tier);

            // Only load once history has finished selecting a default epoch.
            if (!histProv.isLoading) {
              final selectedEpoch = histProv.selectedEpoch;
              if (selectedEpoch != null) {
                final alreadyShowing =
                    provider.currentEpoch == selectedEpoch.toInt() && provider.tier == tierProv.tier;
                if (!alreadyShowing) {
                  unawaited(provider.loadForSelectedEpoch(selectedEpoch));
                }
              }
            }

            return provider;
          },
        ),

        ProxyProvider3<WalletConnectionProvider, SolanaClientService, SolanaWalletAdapterService, TxRouter>(
          update: (_, walletConn, sol, mwa, _) =>
              TxRouter(walletConn: walletConn, rpc: sol.rpcClient, seedVault: SeedVault.instance, mwa: mwa),
        ),

        // -------------------------------------------------------------------
        // Claim flow (build -> sign -> send -> confirm)
        // -------------------------------------------------------------------
        ProxyProvider2<WalletProvider, TxRouter, ClaimTxService>(
          update: (_, wallet, router, _) =>
              ClaimTxService(walletProvider: wallet, buildClaimTx: buildClaimTx, txRouter: router),
        ),

        ChangeNotifierProxyProvider<ClaimTxService, ClaimProvider>(
          create: (ctx) => ClaimProvider(claimTxService: ctx.read<ClaimTxService>()),
          update: (_, service, provider) {
            provider ??= ClaimProvider(claimTxService: service);
            provider.attachService(service);
            return provider;
          },
        ),

        // service
        Provider<PlayerPredictionsService>(
          create: (ctx) => PlayerPredictionsService(ctx.read<SolanaWsService>()),
        ),

        // provider
        ChangeNotifierProxyProvider3<
          ProfilePdaProvider,
          PlayerPredictionsService,
          LiveFeedProvider,
          PlayerPredictionsProvider
        >(
          lazy: false,
          create: (ctx) {
            final p = PlayerPredictionsProvider(
              service: ctx.read<PlayerPredictionsService>(),
              profilePda: ctx.read<ProfilePdaProvider>(),
            );
            p.attach();
            p.attachLiveFeed(ctx.read<LiveFeedProvider>());

            return p;
          },
          update: (ctx, profile, service, live, provider) {
            provider!.attachLiveFeed(live);
            return provider;
          },
        ),

        ChangeNotifierProvider(lazy: false, create: (_) => ProfileStatsProvider()),
      ],
      child: const AppBootstrapper(child: MainApp()),
    ),
  );
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key, required this.child});
  final Widget child;

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_started) return;
      _started = true;

      unawaited(context.read<WalletConnectionProvider>().tryAutoConnect());

      // 1) Load tier first (needed to know which LiveFeed PDA to include)
      await context.read<TierProvider>().load();
      final tier = context.read<TierProvider>().tier;

      // 2) Boot snapshot optimization (config + livefeed)
      try {
        final snap = await context.read<BootSnapshotService>().fetchInitial(tier: tier);
        context.read<ConfigProvider>().applySnapshot(snap.config);
        context.read<LiveFeedProvider>().applySnapshot(tier: snap.liveFeedTier, model: snap.liveFeed);
      } catch (_) {
        // Optimization only.
      }

      // 2.5) Start LiveFeed AFTER snapshot attempt
      context.read<LiveFeedProvider>().start();

      context.read<GameHistoryProvider>().start();

      // 3) Start long-running services
      context.read<EpochClockService>().start();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,
      initialRoute: '/boot',
      routes: {
        '/boot': (_) => const BootScreen(),
        '/home': (_) => const RootShell(),
        if (kDebugMode) '/debug-resolution': (_) => const GameResolutionDebugScreen(),
      },
      builder: (context, child) {
        return AppBackground(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
