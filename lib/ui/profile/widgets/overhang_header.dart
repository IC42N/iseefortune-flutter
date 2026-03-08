import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/profile_header.dart';

class ProfileOverhangHeader extends StatelessWidget {
  const ProfileOverhangHeader({
    super.key,
    required this.handle,
    required this.subtitle,
    required this.accent,
    required this.onClose,
    this.height = 150,
    this.horizontalPadding = 10,
  });

  final String handle;
  final String subtitle;
  final Color accent;
  final VoidCallback onClose;
  final double height;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        height: height,
        child: ProfileHeader(handle: handle, subtitle: subtitle, accent: accent, onClose: onClose),
      ),
    );
  }
}
