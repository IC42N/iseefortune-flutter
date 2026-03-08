// lib/ui/game/submit_prediction/steps/step_choose_selection.dart

import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/providers/live_feed_provider.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_builder.dart';
import 'package:iseefortune_flutter/services/live_feed/live_feed_vm_types.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/helpers/submit_prediciton_state.dart';
import 'package:iseefortune_flutter/ui/game/submit_prediction/widgets/number_picker.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:provider/provider.dart';

class StepChooseSelection extends StatefulWidget {
  const StepChooseSelection({super.key});

  @override
  State<StepChooseSelection> createState() => _StepChooseSelectionState();
}

class _StepChooseSelectionState extends State<StepChooseSelection> {
  /// Last domain we applied into SubmitPredictionState.
  List<int> _lastAppliedSelectable = const [];

  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleSyncSelectableDomain();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSyncSelectableDomain();
  }

  @override
  void didUpdateWidget(covariant StepChooseSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSyncSelectableDomain();
  }

  void _scheduleSyncSelectableDomain() {
    if (_syncScheduled) return;
    _syncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      _syncSelectableDomainNow();
    });
  }

  void _syncSelectableDomainNow() {
    final liveFeed = context.read<LiveFeedProvider>().liveFeed;
    final config = context.read<ConfigProvider>().config;
    if (liveFeed == null || config == null) return;

    final LiveFeedVM vm = buildLiveFeedVM(
      liveFeed: liveFeed,
      primaryRollOverNumber: config.primaryRollOverNumber,
    );

    final vmSelectable = [...vm.selectableNumbers]..sort();
    if (vmSelectable.isEmpty) return;

    if (_listEqualsInt(vmSelectable, _lastAppliedSelectable)) return;

    final s = context.read<SubmitPredictionState>();
    if (!_listEqualsInt(vmSelectable, s.selectableNumbers)) {
      s.setSelectableNumbers(vmSelectable);
    }

    _lastAppliedSelectable = List<int>.from(vmSelectable);
  }

  @override
  Widget build(BuildContext context) {
    final liveFeed = context.select<LiveFeedProvider, dynamic>((p) => p.liveFeed);
    final config = context.select<ConfigProvider, dynamic>((p) => p.config);

    final LiveFeedVM vm = buildLiveFeedVM(
      liveFeed: liveFeed,
      primaryRollOverNumber: config.primaryRollOverNumber,
    );

    _scheduleSyncSelectableDomain();

    // IMPORTANT: snapshot list so rebuilds happen when Set mutates in-place.
    final selectedSnapshot = context.select<SubmitPredictionState, List<int>>(
      (s) => (s.numbers.toList()..sort()),
    );

    final inferredHL = context.select<SubmitPredictionState, HighLowChoice?>((s) => s.inferredHighLow);
    final inferredEO = context.select<SubmitPredictionState, EvenOddChoice?>((s) => s.inferredEvenOdd);

    final action = context.select<SubmitPredictionState, PredictionAction>((s) => s.action);
    final baseCount = context.select<SubmitPredictionState, int>((s) => s.baseSelectionCount);

    // ✅ Ticket-change + single selection special mode
    final bool isChangeSingleMode = action == PredictionAction.changeNumber && baseCount == 1;

    final allowed = vm.selectableNumbers.toSet();
    final selectedSet = selectedSnapshot.toSet();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick tiles hidden in "change single" mode (must pick exactly 1 and replace via taps)
        if (!isChangeSingleMode) ...[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _QuickTile(
                label: 'LOW',
                selected: inferredHL == HighLowChoice.low,
                onTap: () => context.read<SubmitPredictionState>().selectLow(),
              ),
              _QuickTile(
                label: 'HIGH',
                selected: inferredHL == HighLowChoice.high,
                onTap: () => context.read<SubmitPredictionState>().selectHigh(),
              ),
              _QuickTile(
                label: 'EVEN',
                selected: inferredEO == EvenOddChoice.even,
                onTap: () => context.read<SubmitPredictionState>().selectEven(),
              ),
              _QuickTile(
                label: 'ODD',
                selected: inferredEO == EvenOddChoice.odd,
                onTap: () => context.read<SubmitPredictionState>().selectOdd(),
              ),
              _QuickTile(
                label: 'CLEAR',
                selected: false,
                onTap: () => context.read<SubmitPredictionState>().clearNumbers(),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Optional: tiny hint line (remove if you want it totally clean)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tap a new number to switch your prediction.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacityCompat(0.60),
              ),
            ),
          ),
        ],

        NumberGrid(
          selected: selectedSet,
          allowed: allowed,
          onTap: (n) {
            if (!allowed.contains(n)) return;

            final s = context.read<SubmitPredictionState>();

            // ✅ Change-ticket + single selection:
            // Always "replace" with the tapped number.
            // No multi-select, no toggle-to-empty.
            if (isChangeSingleMode) {
              if (s.numbers.length == 1 && s.numbers.contains(n)) return; // unchanged
              s.selectSingleNumber(n);
              return;
            }

            // Existing behavior for normal flows:
            // - If nothing selected yet, behave like "single replace"
            // - If 1 selected and it's different, become "split" (add second)
            // - If already split, cap at 8
            if (s.numbers.isEmpty) {
              s.selectSingleNumber(n);
              return;
            }

            if (s.numbers.length == 1) {
              if (s.numbers.contains(n)) {
                s.selectSingleNumber(n); // toggle off behavior for normal flow
                return;
              }
              s.toggleNumber(n);
              return;
            }

            if (!s.numbers.contains(n) && s.numbers.length >= 8) return;

            s.toggleNumber(n);
          },
        ),

        const SizedBox(height: 14),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFBFB47B).withOpacityCompat(0.18)
              : Colors.white.withOpacityCompat(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFFBFB47B).withOpacityCompat(0.65)
                : Colors.white.withOpacityCompat(0.12),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: selected ? const Color(0xFFBFB47B) : Colors.white.withOpacityCompat(0.85),
            fontWeight: FontWeight.w400,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

bool _listEqualsInt(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
