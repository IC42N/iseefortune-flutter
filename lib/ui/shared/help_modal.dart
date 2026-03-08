import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

Future<void> showHelpModal(
  BuildContext context, {
  required String title,
  required String message,
  List<String>? bullets,
  String buttonText = 'Got it',
  IconData icon = Icons.info_outline_rounded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomPad = MediaQuery.of(ctx).padding.bottom;

      return Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomPad),
        child: _SheetSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white.withOpacityCompat(0.85)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacityCompat(0.82),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (bullets != null && bullets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...bullets.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: TextStyle(color: Colors.white.withOpacityCompat(0.75))),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                color: Colors.white.withOpacityCompat(0.78),
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: AppColors.goldColor,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1A).withOpacityCompat(0.92),
            border: Border.all(color: Colors.white.withOpacityCompat(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacityCompat(0.45),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
