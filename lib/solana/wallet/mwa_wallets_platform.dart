// lib/solana/wallet/mwa_wallets_platform.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

/// Canonical model for MWA wallet apps in your Flutter UI.
class MwaWalletApp {
  final String label;
  final String packageName;
  final Widget? icon;

  const MwaWalletApp({required this.label, required this.packageName, this.icon});

  factory MwaWalletApp.fromPlatformMap(Map<dynamic, dynamic> m) {
    final label = (m['name'] ?? '').toString();
    final pkg = (m['package'] ?? '').toString();
    final b64 = (m['iconPngBase64'] ?? '').toString();

    Widget iconWidget = const Icon(Icons.account_balance_wallet_outlined);

    if (b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: 26,
            height: 26,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        );
      } catch (_) {
        // Keep default icon
      }
    }

    return MwaWalletApp(label: label, packageName: pkg, icon: iconWidget);
  }
}

class MwaWalletsPlatform {
  static const MethodChannel _ch = MethodChannel('mwa_wallets');

  /// Returns installed MWA-capable wallet apps as UI-friendly models.
  static Future<List<MwaWalletApp>> getInstalledWallets() async {
    final list = await _ch.invokeMethod<List<dynamic>>('getInstalledMwaWallets');
    final items = list ?? const [];

    final wallets = items
        .whereType<Map<dynamic, dynamic>>()
        .map(MwaWalletApp.fromPlatformMap)
        .where((w) => w.packageName.isNotEmpty)
        .toList();

    wallets.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return wallets;
  }

  /// Force-launch a specific wallet app (Android plugin uses ACTION_VIEW solana-wallet: + package).
  /// Returns true if launched, false otherwise.
  // static Future<bool> launchWallet({required String packageName}) async {
  //   if (packageName.isEmpty) return false;

  //   try {
  //     final ok = await _ch.invokeMethod<bool>('launchMwaWallet', <String, dynamic>{
  //       'packageName': packageName,
  //     });
  //     return ok == true;
  //   } catch (_) {
  //     return false;
  //   }
  // }

  static Future<void> startMwaAssociation({required String associationUri, String? walletPackage}) async {
    await _ch.invokeMethod<void>('startMwaAssociation', <String, dynamic>{
      'associationUri': associationUri,
      'walletPackage': walletPackage,
    });
  }
}

/// Shows a bottom sheet picker (if needed) and returns the chosen wallet package name.
/// - null => user cancelled or no wallets
/// - "app.phantom" / "app.backpack.mobile" => selected wallet package
Future<String?> showMwaWalletPickerAndReturnPackage(BuildContext context) async {
  final wallets = await MwaWalletsPlatform.getInstalledWallets();
  if (!context.mounted) return null;

  if (wallets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Solana wallet apps found')));
    return null;
  }

  if (wallets.length == 1) return wallets.first.packageName;

  wallets.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomPad = MediaQuery.of(ctx).padding.bottom;

      return Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomPad),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF0B0F1A),
            border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header + close X
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 10, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Wallet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                  itemCount: wallets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (_, i) {
                    final w = wallets[i];

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: Colors.white.withOpacityCompat(0.04),
                      leading: w.icon ?? const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(w.label),
                      subtitle: Text(
                        w.packageName,
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      onTap: () => Navigator.of(ctx).pop(w.packageName),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
