import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class MaybeLinkText extends StatelessWidget {
  const MaybeLinkText({super.key, required this.text, this.url});
  final String text;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacityCompat(0.70),
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
          height: 1.3,
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url!);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.goldColor.withOpacityCompat(0.92),
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          height: 1.3,
          // decoration: TextDecoration.underline,
          // decorationColor: AppColors.goldColor.withOpacityCompat(0.60),
        ),
      ),
    );
  }
}
