// lib/ui/shared/mwa_wallet_picker.dart
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/solana/wallet/mwa_wallets_platform.dart';

Future<String?> pickWalletPackage({required BuildContext context, required String? savedPackage}) async {
  final wallets = await MwaWalletsPlatform.getInstalledWallets();
  if (!context.mounted) return null;

  if (savedPackage != null && savedPackage.isNotEmpty) {
    final stillInstalled = wallets.any((w) => w.packageName == savedPackage);
    if (stillInstalled) return savedPackage;
  }

  // fallback to picker
  return showMwaWalletPickerAndReturnPackage(context);
}
