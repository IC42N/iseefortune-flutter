import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class ChangeTicketCard extends StatefulWidget {
  const ChangeTicketCard({
    super.key,
    required this.count,
    required this.disabled,
    required this.onUse,
    this.initiallyExpanded = false,
  });

  final int count;
  final bool disabled;
  final VoidCallback onUse;
  final bool initiallyExpanded;

  @override
  State<ChangeTicketCard> createState() => _ChangeTicketCardState();
}

class _ChangeTicketCardState extends State<ChangeTicketCard> with TickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggle() {
    if (!mounted) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Colors.white.withOpacityCompat(0.95),
      fontWeight: FontWeight.w900,
      fontSize: 13,
    );

    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white.withOpacityCompat(0.75),
      fontWeight: FontWeight.w600,
      fontSize: 11,
      height: 1.25,
    );

    // Rare item palette
    const c1 = Color(0xFF2CE6FF);
    const c2 = Color(0xFF8544BD);
    const c3 = Color(0xFFC541A8);

    final innerBg = Colors.black.withOpacityCompat(0.22);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacityCompat(0.55),
        border: Border.all(
          width: 1.4,
          color: widget.disabled ? Colors.white.withOpacityCompat(0.12) : c2.withOpacityCompat(0.75),
        ),
        boxShadow: widget.disabled
            ? []
            : [
                BoxShadow(color: c2.withOpacityCompat(0.30), blurRadius: 5, spreadRadius: 1),
                BoxShadow(color: c1.withOpacityCompat(0.15), blurRadius: 8, spreadRadius: 2),
              ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: widget.disabled
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c1.withOpacityCompat(0.06),
                    c2.withOpacityCompat(0.05),
                    c3.withOpacityCompat(0.06),
                  ],
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------
            // Header (always visible)
            // Tap anywhere to expand/collapse
            // ----------------------------
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                // Extra padding makes the tap target feel easy
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_activity_rounded,
                      size: 18,
                      color: widget.disabled ? Colors.white.withOpacityCompat(0.5) : c1,
                    ),
                    const SizedBox(width: 8),
                    Text('Change Ticket', style: titleStyle),
                    const Spacer(),

                    // Count pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: innerBg,
                        border: Border.all(
                          color: widget.disabled
                              ? Colors.white.withOpacityCompat(0.10)
                              : Colors.white.withOpacityCompat(0.16),
                        ),
                      ),
                      child: Text(
                        'x${widget.count}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          color: widget.disabled ? Colors.white.withOpacityCompat(0.55) : Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Chevron
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0, // 0.5 = 180 degrees
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Colors.white.withOpacityCompat(widget.disabled ? 0.25 : 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------
            // Expand/collapse body
            // ----------------------------
            SizedBox(
              width: double.infinity, // 🔒 prevents any left-grow feel
              child: ClipRect(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: _expanded ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) {
                    return Align(
                      alignment: Alignment.topCenter,
                      heightFactor: t, // ✅ height only
                      child: Opacity(opacity: t, child: child), // ✅ fade only
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change tickets are a powerful tool as switching your prediction to a number with less players can greatly increase pot share if it wins.',
                          style: bodyStyle,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.disabled ? null : widget.onUse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.disabled
                                  ? Colors.white.withOpacityCompat(0.08)
                                  : Colors.white.withOpacityCompat(0.10),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: BorderSide(
                                color: widget.disabled
                                    ? Colors.white.withOpacityCompat(0.12)
                                    : c2.withOpacityCompat(0.6),
                              ),
                            ),
                            child: const Text(
                              'Use Change Ticket',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
