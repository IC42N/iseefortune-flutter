import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iseefortune_flutter/models/game/game_pda_model.dart';
import 'package:iseefortune_flutter/models/game_resolution/game_resolution_model.dart';
import 'package:iseefortune_flutter/providers/claim/claim_provider.dart';
import 'package:iseefortune_flutter/providers/config_provider.dart';
import 'package:iseefortune_flutter/providers/profile/profile_predictions_provider.dart';
import 'package:iseefortune_flutter/providers/tier_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_provider.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_chain_service.dart';
import 'package:iseefortune_flutter/ui/game_resolution/digital_ring.dart';
import 'package:iseefortune_flutter/ui/game_resolution/result_copy.dart';
import 'package:iseefortune_flutter/ui/game_resolution/result_copy_widget.dart';
import 'package:iseefortune_flutter/ui/shared/cosmic_modal_shell.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';
import 'package:provider/provider.dart';

class GameResolutionModal extends StatefulWidget {
  const GameResolutionModal({
    super.key,
    required this.args,
    this.resultFutureOverride,
    this.processingMessage,
  });

  final GameResolutionModalArgs args;

  final Future<GameResolutionResult>? resultFutureOverride;
  final String? processingMessage;

  static Future<void> show(
    BuildContext context, {
    required GameResolutionModalArgs args,
    Future<GameResolutionResult>? resultFutureOverride,
    String? processingMessage,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameResolutionModal(
        args: args,
        resultFutureOverride: resultFutureOverride,
        processingMessage: processingMessage,
      ),
    );
  }

  @override
  State<GameResolutionModal> createState() => _GameResolutionModalState();
}

enum _Phase { processing, revealing, finalState, error }

class _GameResolutionModalState extends State<GameResolutionModal> with TickerProviderStateMixin {
  String? _claimPredictionPda; // prediction PDA (base58)
  _Phase _phase = _Phase.processing;

  int _displayNumber = 0; // 0..9
  int _ringIndex = 0; // 0..9

  GameResolutionResult? _result;
  ResultCopy? _resultCopy; // locked once per modal session

  Timer? _spinTimer;
  Timer? _ringTimer;

  late final AnimationController _blinkController;
  late final Animation<double> _blinkOpacity;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _blinkOpacity = Tween<double>(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));
    _blinkController.repeat(reverse: true);

    _startSpinning();
    _waitForResult();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _ringTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  void _startSpinning() {
    _ringTimer?.cancel();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted) return;
      setState(() => _ringIndex = (_ringIndex + 1) % 10);
    });
  }

  Future<void> _waitForResult() async {
    try {
      final fut = widget.resultFutureOverride ?? _resolveReal();

      final res = await fut;
      if (!mounted) return;

      _spinTimer?.cancel();
      _ringTimer?.cancel();

      // compute + lock result copy ONCE per modal session
      final seed = DateTime.now().microsecondsSinceEpoch;
      final copy = getResultCopy(
        ResultCopyContext(
          outcome: (res.outcome == GameResolutionOutcome.win) ? 'win' : 'miss',
          isRollover: res.outcome == GameResolutionOutcome.rollover,
          payoutLamports: BigInt.from(res.payoutLamports ?? 0),
          seed: seed,
        ),
      );

      setState(() {
        _phase = _Phase.revealing;
        _result = res;
        _resultCopy = copy;
      });

      await _slowdownTo(res.winningNumber);
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      setState(() => _phase = _Phase.finalState);
    } catch (_) {
      if (!mounted) return;
      _spinTimer?.cancel();
      _ringTimer?.cancel();
      setState(() => _phase = _Phase.error);
    }
  }

  /// REAL resolver (epoch route).
  Future<GameResolutionResult> _resolveReal() async {
    final resolvedSvc = context.read<ResolvedGameService>();

    final resolvedKey = widget.args.resolvedGamePda; // Ed25519HDPublicKey
    final resolvedKey58 = resolvedKey.toBase58();

    final wallet = context.read<WalletProvider>();
    final playerPubkey = wallet.pubkey;
    final walletConnected = wallet.isConnected && (playerPubkey?.isNotEmpty ?? false);

    // 1) Get the resolved game account (snapshot then WS fallback)
    ResolvedGameModel rg;
    try {
      final snap = await resolvedSvc.fetchResolvedGameByPubkey(resolvedKey58, commitment: 'confirmed');
      if (snap.isResolved) {
        rg = snap;
      } else {
        rg = await _waitForResolvedViaWs(resolvedSvc, resolvedKey58);
      }
    } catch (_) {
      rg = await _waitForResolvedViaWs(resolvedSvc, resolvedKey58);
    }

    // 2) Rollover path overrides everything
    if (rg.isRollover) {
      final config = context.read<ConfigProvider>().config;
      final primaryRollOver = config != null ? config.primaryRollOverNumber : 0;

      // clear claim state just in case
      _setClaimPredictionPda(null);

      return GameResolutionResult(
        winningNumber: rg.winningNumber.clamp(0, 9),
        outcome: GameResolutionOutcome.rollover,
        rolloverNumbers: [primaryRollOver, rg.secondaryRolloverNumber],
        winnersCount: rg.totalWinners,
      );
    }

    // 3) Spectator / disconnected path
    if (!walletConnected) {
      _setClaimPredictionPda(null);
      return GameResolutionResult(
        winningNumber: rg.winningNumber.clamp(0, 9),
        outcome: GameResolutionOutcome.generic,
        winnersCount: rg.totalWinners,
      );
    }

    // 4) Find the player's prediction for THIS game chain + tier
    final tier = context.read<TierProvider>().tier;
    final preds = context.read<PlayerPredictionsProvider>();

    final gameEpoch = rg.firstEpochInChain;
    final predictionPda = preds.findPredictionPdaForGameEpoch(
      gameEpoch: gameEpoch,
      tier: tier,
      playerPubkey: playerPubkey!,
    );

    if (predictionPda == null) {
      _setClaimPredictionPda(null);
      return GameResolutionResult(
        winningNumber: rg.winningNumber.clamp(0, 9),
        outcome: GameResolutionOutcome.generic, // connected but didn't play this game
        winnersCount: rg.totalWinners,
      );
    }

    final predModel = preds.byPubkey[predictionPda];
    if (predModel == null) {
      // not decoded yet; you can treat as generic OR force fetch, but generic is safest here
      _setClaimPredictionPda(null);
      return GameResolutionResult(
        winningNumber: rg.winningNumber.clamp(0, 9),
        outcome: GameResolutionOutcome.generic,
        winnersCount: rg.totalWinners,
      );
    }

    // 5) Win/loss check using selectionsMask (fast)
    final n = rg.winningNumber.clamp(0, 9);
    final didWin = (predModel.selectionsMask & (1 << n)) != 0;

    if (!didWin) {
      _setClaimPredictionPda(null);
      return GameResolutionResult(
        winningNumber: n,
        outcome: GameResolutionOutcome.loss,
        winnersCount: rg.totalWinners,
      );
    }

    // 6) Winner: prefetch claim now (payout + unsigned message cached in provider)
    final claimProvider = context.read<ClaimProvider>();

    _setClaimPredictionPda(predictionPda);

    // Fire and await so payout is ready for copy/UI.
    // If you want zero extra wait before reveal animation, you can NOT await it
    // and just let payout pop in a split second later.
    await claimProvider.prefetchClaim(predictionPda);

    final claimState = claimProvider.stateFor(predictionPda);

    return GameResolutionResult(
      winningNumber: n,
      outcome: GameResolutionOutcome.win,
      payoutLamports: claimState.payoutLamports,
      winnersCount: rg.totalWinners,
    );
  }

  Future<ResolvedGameModel> _waitForResolvedViaWs(ResolvedGameService svc, String pubkey58) async {
    final stream = await svc.subscribeResolvedGameByPubkey(pubkey58, commitment: 'confirmed');
    return stream.firstWhere((m) => m.isResolved).timeout(const Duration(seconds: 45));
  }

  void _setClaimPredictionPda(String? pda) {
    if (!mounted) return;
    setState(() => _claimPredictionPda = pda);
  }

  int _clamp09(int n) => n.clamp(0, 9);

  Future<void> _slowdownTo(int finalNumberRaw) async {
    final finalNumber = _clamp09(finalNumberRaw);

    const delays = <int>[60, 70, 85, 105, 135, 180, 240, 320, 420, 520];
    int idx = _ringIndex;

    for (final d in delays) {
      if (!mounted) return;
      idx = (idx + 1) % 10;

      setState(() {
        _ringIndex = idx;
        _displayNumber = idx;
      });

      await Future.delayed(Duration(milliseconds: d));
    }

    if (!mounted) return;

    int safety = 0;
    int slow = 180;

    while (idx != finalNumber && safety < 30) {
      if (!mounted) return;

      idx = (idx + 1) % 10;
      setState(() {
        _ringIndex = idx;
        _displayNumber = idx;
      });

      await Future.delayed(Duration(milliseconds: slow));
      slow = (slow + 40).clamp(180, 520);
      safety++;
    }

    if (!mounted) return;

    setState(() {
      _ringIndex = finalNumber;
      _displayNumber = finalNumber;
    });

    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 220));
  }

  bool get _canClose => _phase == _Phase.finalState || _phase == _Phase.error;

  Widget _subtitleWidget(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final subStyle = t.bodyMedium?.copyWith(
      fontSize: 14,
      color: Colors.white.withOpacityCompat(0.68),
      fontWeight: FontWeight.w600,
    );

    switch (_phase) {
      case _Phase.processing:
        return Text('Finalizing on-chain…', style: subStyle);

      case _Phase.revealing:
        return Text('Revealing…', style: subStyle);

      case _Phase.finalState:
        final r = _result;
        if (r == null) return const SizedBox.shrink();

        final n = _clamp09(r.winningNumber);
        final numberCol = numberColor(n, intensity: 1.0).withOpacityCompat(0.95);

        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: subStyle,
            children: [
              const TextSpan(text: 'Winning number: '),
              TextSpan(
                text: '$n',
                style: subStyle?.copyWith(
                  color: numberCol,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 8, color: numberCol.withOpacityCompat(0.6))],
                ),
              ),
            ],
          ),
        );

      case _Phase.error:
        return Text('Could not fetch results. Please try again.', style: subStyle);
    }
  }

  Widget _finalizedWidget(BuildContext context) {
    final processingCopy = widget.processingMessage ?? 'Fate is being determined…';
    final finalStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withOpacityCompat(0.82),
      fontWeight: FontWeight.w700,
    );

    if (_phase == _Phase.processing || _phase == _Phase.revealing) {
      return FadeTransition(
        opacity: _blinkOpacity,
        child: Text(processingCopy, style: finalStyle, textAlign: TextAlign.center),
      );
    }

    if (_phase == _Phase.finalState && _result != null && _resultCopy != null) {
      return ResultCopyText(copy: _resultCopy!, outcome: _result!.outcome);
    }

    if (_phase == _Phase.error) {
      return Text(
        'We couldn\'t load the resolved game. Close and try again.',
        style: finalStyle,
        textAlign: TextAlign.center,
      );
    }

    return Text(processingCopy, style: finalStyle, textAlign: TextAlign.center);
  }

  @override
  Widget build(BuildContext context) {
    final isWin = _phase == _Phase.finalState && _result?.outcome == GameResolutionOutcome.win;

    final predictionPda = _claimPredictionPda;
    final canShowClaim = isWin && predictionPda != null;

    final claimProvider = context.watch<ClaimProvider>();
    final claimState = (predictionPda == null) ? ClaimState.idle : claimProvider.stateFor(predictionPda);

    return CosmicModalShell(
      title: '',
      subtitle: '',
      hueDeg: 45,
      showStars: true,
      handsTop: 92.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 26),
            Text(
              'EPOCH ${widget.args.anchorEpoch}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.goldColor.withOpacityCompat(0.78),
                letterSpacing: 2.0,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            _subtitleWidget(context),

            const SizedBox(height: 18),
            DigitRingOrb(number: _displayNumber, ringIndex: _ringIndex, isFinal: _phase == _Phase.finalState),
            const SizedBox(height: 24),

            _finalizedWidget(context),

            if (canShowClaim) ...[
              const SizedBox(height: 18),

              if (claimState.isSuccess)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2FE36D).withOpacityCompat(0.35), width: 1.2),
                    color: const Color(0xFF2FE36D).withOpacityCompat(0.10),
                  ),
                  child: Text(
                    'Successfully claimed',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF2FE36D).withOpacityCompat(0.92),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (claimState.isBusy)
                        ? null
                        : () => claimProvider.claimForPredictionPDA(predictionPda),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2FE36D).withOpacityCompat(0.90),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      claimState.isAwaitingSignature
                          ? 'Awaiting signature…'
                          : claimState.isPreparing
                          ? 'Preparing…'
                          : 'Claim winnings',
                    ),
                  ),
                ),

              if (claimState.isError && claimState.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  claimState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFF5A5A).withOpacityCompat(0.90),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 32),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canClose ? () => Navigator.of(context).pop() : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: Colors.white.withOpacityCompat(_canClose ? 0.12 : 0.09),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  foregroundColor: Colors.white.withOpacityCompat(_canClose ? 0.90 : 0.50),
                ),
                child: Text(_canClose ? 'Close' : 'Resolving…'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
