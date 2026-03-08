import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class InlineLink extends StatelessWidget {
  const InlineLink({super.key, required this.label, required this.url});

  final String label;
  final String url;

  Future<void> _open() async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        label,
        style: TextStyle(color: AppColors.skrAccent, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }
}
