import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> copyToClipboardWithToast(BuildContext context, String text, {String label = 'Address'}) async {
  await Clipboard.setData(ClipboardData(text: text));

  if (!context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 1)));
}

// Open signature in solana fm
Future<void> openOnSolanaFM(BuildContext context, String sigBase58) async {
  final url = Uri.parse('https://solana.fm/tx/$sigBase58'); // add ?cluster=devnet-solana if needed
  try {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      // Fallback to default mode
      final ok2 = await launchUrl(url);
      if (!ok2 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open SolanaFM')));
      }
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open SolanaFM')));
    }
  }
}
