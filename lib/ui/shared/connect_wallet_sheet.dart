// lib/ui/shared/connect_wallet_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/ui/shared/pill.dart';
import 'package:iseefortune_flutter/utils/solana/pubkey.dart';
import 'package:provider/provider.dart';

import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:solana_seed_vault/solana_seed_vault.dart';

Future<void> showConnectWalletSheet(BuildContext context) async {
  final conn = context.read<WalletConnectionProvider>();

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ConnectWalletSheet(),
  ).whenComplete(() {
    // If user dismisses the sheet mid-connect, stop the spinner and unlock UI.
    if (!conn.isConnected && conn.isConnecting && !conn.isDisconnecting) {
      conn.cancelConnectAttempt(reason: 'connect sheet dismissed');
    }
  });
}

class _ConnectWalletSheet extends StatelessWidget {
  const _ConnectWalletSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomPad),
      child: _SheetSurface(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 10, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [_Header(), _Body()],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.account_balance_wallet_outlined, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white54),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<WalletConnectionProvider>();
    final wallet = context.watch<WalletProvider>();

    final isConnected = conn.isConnected;
    final isBusy = conn.isBusy;

    // Note: wallet.pubkey should mirror conn.pubkey after attachWalletConnection is wired
    final pubkey = wallet.pubkey ?? conn.pubkey;
    final err = conn.uiError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isConnected) ...[
          _ConnectedCard(pubkey: pubkey),
          const SizedBox(height: 12),
          _DisconnectRow(isBusy: isBusy),
          const SizedBox(height: 12),
        ] else ...[
          _ConnectOptions(isBusy: isBusy),
          const SizedBox(height: 12),
        ],
        if (err != null) ...[_UiErrorBox(err: err)],
      ],
    );
  }
}

class _ConnectOptions extends StatelessWidget {
  const _ConnectOptions({required this.isBusy});
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final conn = context.read<WalletConnectionProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Choose a connection method', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        // Seed Vault
        FutureBuilder<bool>(
          future: SeedVault.instance.isAvailable(allowSimulated: true),
          builder: (context, snap) {
            final available = snap.data == true;
            final checking = snap.connectionState != ConnectionState.done;

            final enabled = !isBusy && available;
            final subtitle = checking
                ? 'Checking availability…'
                : available
                ? 'Best on Solana Mobile'
                : 'Not available on this device';

            final trailing = available ? const Icon(Icons.chevron_right) : const Pill(text: 'None');

            return _OptionTile(
              enabled: enabled,
              icon: Icons.verified_user_outlined,
              title: 'Seed Vault',
              subtitle: subtitle,
              trailing: trailing,
              onTap: () async {
                await conn.connectSeedVault();
                if (context.mounted && conn.isConnected) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        ),

        const SizedBox(height: 10),

        // Wallet app via MWA
        _OptionTile(
          enabled: !isBusy,
          icon: Icons.open_in_new_rounded,
          title: 'Wallet App',
          subtitle: 'Supports Phantom, Backpack, Solflare, Jupiter, etc.',
          trailing: const Pill(text: 'BETA'),
          onTap: () async {
            final ok = await _confirmWalletAppBeta(context);
            if (!ok) return;

            await conn.connect(context);

            if (!context.mounted) return;

            if (conn.isConnected) {
              final pubkey = conn.pubkey;
              final shortAddr = shortPDA(pubkey ?? '');

              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Wallet $shortAddr connected'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    backgroundColor: const Color.fromARGB(255, 60, 18, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                );

              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.pubkey});
  final String? pubkey;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    final sol = wallet.solBalanceText;
    final usd = wallet.usdBalance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
        color: const Color(0xFF0B0F1A).withOpacityCompat(0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connected', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          // pubkey row
          Row(
            children: [
              Expanded(
                child: Text(
                  shortBlockHash(pubkey ?? '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacityCompat(0.85)),
                ),
              ),
              IconButton(
                tooltip: 'Copy address',
                onPressed: pubkey == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: pubkey!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Address copied')));
                        }
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // balance
          Row(
            children: [
              Expanded(
                child: Text('$sol SOL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              if (usd != null)
                Text(
                  '\$${usd.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white.withOpacityCompat(0.75)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisconnectRow extends StatelessWidget {
  const _DisconnectRow({required this.isBusy});
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final conn = context.read<WalletConnectionProvider>();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isBusy
                ? null
                : () async {
                    await conn.disconnect(revoke: conn.kind == WalletKind.seedVault);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacityCompat(0.22)),
            ),
            child: const Text('Disconnect'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: isBusy
                ? null
                : () {
                    // You can later route to a "Wallet" screen.
                    Navigator.of(context).pop();
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.goldColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _UiErrorBox extends StatelessWidget {
  const _UiErrorBox({required this.err});
  final WalletConnectError err;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withOpacityCompat(0.12),
        border: Border.all(color: Colors.red.withOpacityCompat(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(err.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(err.message, style: TextStyle(color: Colors.white.withOpacityCompat(0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.white : Colors.white.withOpacityCompat(0.45);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
          color: const Color(0xFF0B0F1A).withOpacityCompat(0.40),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: fg.withOpacityCompat(0.85))),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0B0F1A).withOpacityCompat(0.92),
        border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacityCompat(0.45),
          ),
        ],
      ),
      child: child,
    );
  }
}

Future<bool> _confirmWalletAppBeta(BuildContext context) async {
  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Wallet App (Beta)'),
      content: const Text(
        'Wallet App connection is available and working, but it is still in beta. '
        'Some wallets or flows may behave differently while support continues to improve.',
      ),
      actions: [ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue'))],
    ),
  );
  return res == true;
}
