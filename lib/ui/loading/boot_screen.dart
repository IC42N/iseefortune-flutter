import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/services/epoch_clock_service.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _timedOut = false;
  bool _navigated = false;
  Timer? _timeoutTimer;

  static const Duration _timeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, () {
      if (!mounted) return;
      // We don't know readiness here without provider values,
      // so we just flip timeout UI and let the Consumer decide.
      setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    super.dispose();
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() => _timedOut = false);

    final tier = context.read<TierProvider>();
    final cfg = context.read<ConfigProvider>();
    final live = context.read<LiveFeedProvider>();
    final clock = context.read<EpochClockService>();

    // 1) Tier (usually local prefs; super fast, but safe to re-run)
    await tier.load();

    // 2) Restart epoch clock sync (don’t assume start() is async)
    clock.stop();
    clock.start();

    // 3) Force config reload (HTTP + restart WS)
    await cfg.reload();

    // 4) Force live feed reload/subscription for the current tier
    //    (method below; add it to LiveFeedProvider)
    await live.forceReload();

    _startTimeoutTimer();
  }

  void _goHomeOnce(BuildContext context) {
    if (_navigated) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<EpochClockService, TierProvider, ConfigProvider, LiveFeedProvider>(
      builder: (context, clock, tier, cfg, live, _) {
        // Keep this gate strict so Home never flashes empty state.
        final ready = tier.isReady && cfg.isReady && clock.hasState && live.hasData;

        if (ready) {
          _goHomeOnce(context);
          return const SizedBox.shrink();
        }

        final status = <String>[
          'Config: ${cfg.isReady ? "ok" : (cfg.isLoading ? "loading" : "...")}',
          'Game: ${live.hasData ? "ok" : (live.isLoading ? "loading" : "...")}',
        ].join('  •  ');

        final showRetry = _timedOut;

        return Scaffold(
          backgroundColor: const Color(0xFF101C2E),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Image.asset('assets/icon/loading-icon.png', width: 180, height: 160)),
                    const SizedBox(height: 12),

                    Text(
                      showRetry ? 'Still syncing…' : 'Booting…',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white.withOpacityCompat(0.92)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    Text(
                      status,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacityCompat(0.65)),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 14),

                    if (!showRetry)
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),

                    if (showRetry) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _retry, child: const Text('Retry')),
                      const SizedBox(height: 8),
                      Text(
                        'Network may be slow. We\'ll continue once everything loads.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacityCompat(0.70)),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
