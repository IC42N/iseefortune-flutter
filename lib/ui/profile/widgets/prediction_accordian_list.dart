import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/models/prediction/prediciton_profile_row_vm.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/accordian_body.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/accordian_title.dart';
import 'package:iseefortune_flutter/ui/profile/widgets/in_progress_body.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';

class PredictionAccordionList extends StatelessWidget {
  const PredictionAccordionList({super.key, required this.rows, this.onExpandFetch});

  final List<ProfilePredictionRowVM> rows;

  final Future<void> Function(ProfilePredictionRowVM row)? onExpandFetch;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PredictionAccordionTile(
              key: ValueKey(row.core.pda),
              row: row,
              onExpandFetch: onExpandFetch,
            ),
          ),
      ],
    );
  }
}

class _PredictionAccordionTile extends StatefulWidget {
  const _PredictionAccordionTile({super.key, required this.row, this.onExpandFetch});

  final ProfilePredictionRowVM row;
  final Future<void> Function(ProfilePredictionRowVM row)? onExpandFetch;

  @override
  State<_PredictionAccordionTile> createState() => _PredictionAccordionTileState();
}

class _PredictionAccordionTileState extends State<_PredictionAccordionTile> {
  bool _didFireFetch = false;

  @override
  void didUpdateWidget(covariant _PredictionAccordionTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.row.core.pda != widget.row.core.pda) {
      _didFireFetch = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacityCompat(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacityCompat(0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('pred-${row.core.pda}'),
          showTrailingIcon: false,
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: EdgeInsets.zero,
          onExpansionChanged: (expanded) {
            if (!expanded) return;
            if (_didFireFetch) return;

            _didFireFetch = true;
            final fn = widget.onExpandFetch;
            if (fn != null) Future.microtask(() => fn(row));
          },
          title: AccordianTitle(row: row),
          children: [
            if (row.outcome == PredictionOutcome.progress) // or .inProgress (match your enum)
              const InProgressBody()
            else
              ExpandedBody(row: row),
          ],
        ),
      ),
    );
  }
}
