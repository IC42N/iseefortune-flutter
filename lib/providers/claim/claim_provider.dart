import 'package:flutter/foundation.dart';
import 'package:iseefortune_flutter/api/claim.dart';
import 'package:iseefortune_flutter/services/claim/claim_tx_service.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

enum ClaimPhase { idle, preparing, awaitingSignature, success, error }

@immutable
class ClaimState {
  const ClaimState({
    required this.phase,
    this.errorMessage,
    this.signature,
    this.claimedAt,
    this.payoutLamports,
  });

  final ClaimPhase phase;
  final String? errorMessage;
  final String? signature;
  final DateTime? claimedAt;

  // Only thing modal needs for copy
  final int? payoutLamports;

  bool get isBusy => phase == ClaimPhase.preparing || phase == ClaimPhase.awaitingSignature;
  bool get isPreparing => phase == ClaimPhase.preparing;
  bool get isAwaitingSignature => phase == ClaimPhase.awaitingSignature;
  bool get isSuccess => phase == ClaimPhase.success;
  bool get isError => phase == ClaimPhase.error;

  static const idle = ClaimState(phase: ClaimPhase.idle);

  ClaimState copyWith({
    ClaimPhase? phase,
    String? errorMessage,
    String? signature,
    DateTime? claimedAt,
    int? payoutLamports,
    bool clearError = false,
  }) {
    return ClaimState(
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      signature: signature ?? this.signature,
      claimedAt: claimedAt ?? this.claimedAt,
      payoutLamports: payoutLamports ?? this.payoutLamports,
    );
  }
}

class ClaimProvider extends ChangeNotifier {
  ClaimProvider({required ClaimTxService claimTxService}) : _claimTxService = claimTxService;

  ClaimTxService _claimTxService;

  final Map<String, ClaimState> _byPda = {};
  final Map<String, BuildClaimResponse> _builtByPda = {};

  ClaimState stateFor(String key) => _byPda[key] ?? ClaimState.idle;
  bool isClaiming(String key) => stateFor(key).isBusy;

  BuildClaimResponse? builtFor(String predictionPda) => _builtByPda[predictionPda];

  void attachService(ClaimTxService next) {
    if (identical(_claimTxService, next)) return;
    _claimTxService = next;
  }

  /// Option A: Prefetch unsigned claim + payout, no signing.
  ///
  /// Use this in GameResolutionModal right when you detect a win.
  Future<BuildClaimResponse?> prefetchClaim(String predictionPda) async {
    // If already have it, reuse.
    final existing = _builtByPda[predictionPda];
    if (existing != null) return existing;

    if (isClaiming(predictionPda)) {
      icLogger.i('[claim] prefetch skip (busy) key=$predictionPda');
      return null;
    }

    icLogger.i('[claim] prefetch start key=$predictionPda');
    _byPda[predictionPda] = stateFor(predictionPda).copyWith(clearError: true);
    // keep phase as-is (idle usually)
    notifyListeners();

    try {
      final built = await _claimTxService.buildClaim(predictionPda);

      _builtByPda[predictionPda] = built;

      // IMPORTANT: go back to idle so UI shows "Claim" enabled (not a spinner),
      // but keep payout info available.
      _byPda[predictionPda] = ClaimState(phase: ClaimPhase.idle, payoutLamports: built.payoutLamports);
      notifyListeners();

      icLogger.i('[claim] prefetch done key=$predictionPda payout=${built.payoutLamports}');
      return built;
    } catch (e) {
      final msg = _friendlyClaimError(e);
      icLogger.e('[claim] prefetch error key=$predictionPda msg="$msg" raw=$e');

      _byPda[predictionPda] = ClaimState(phase: ClaimPhase.error, errorMessage: msg);
      notifyListeners();
      return null;
    }
  }

  /// Existing API: Claim for prediction PDA.
  ///
  /// - Profile can keep calling this unchanged.
  /// - Modal can also call it; if you prefetched, it will use the cached payload.
  Future<String?> claimForPredictionPDA(String predictionPda) async {
    if (isClaiming(predictionPda)) {
      icLogger.i('[claim] skip (already busy) key=$predictionPda');
      return null;
    }

    icLogger.i('[claim] start claim key=$predictionPda');
    _byPda[predictionPda] = stateFor(predictionPda).copyWith(phase: ClaimPhase.preparing, clearError: true);
    notifyListeners();

    try {
      final built = _builtByPda[predictionPda];

      final sig = await _claimTxService.claim(
        predictionPda,
        built: built, // <— if null, service will build internally (Profile path)
        onAwaitingSignature: () {
          icLogger.i('[claim] awaiting signature key=$predictionPda');
          _byPda[predictionPda] = stateFor(predictionPda).copyWith(phase: ClaimPhase.awaitingSignature);
          notifyListeners();
        },
      );

      icLogger.i('[claim] success key=$predictionPda sig=$sig');

      // Claim succeeded → you can clear cached build, it’s no longer valid/needed.
      _builtByPda.remove(predictionPda);

      _byPda[predictionPda] = stateFor(
        predictionPda,
      ).copyWith(phase: ClaimPhase.success, signature: sig, claimedAt: DateTime.now());
      notifyListeners();

      return sig;
    } catch (e) {
      if (e is UserCancelledSigning) {
        icLogger.i('[claim] cancelled key=$predictionPda');
        // Keep any prefetched payload so the user can tap claim again instantly.
        _byPda[predictionPda] = stateFor(predictionPda).copyWith(phase: ClaimPhase.idle, clearError: true);
        notifyListeners();
        return null;
      }

      final msg = _friendlyClaimError(e);
      icLogger.e('[claim] error key=$predictionPda msg="$msg" raw=$e');

      _byPda[predictionPda] = stateFor(predictionPda).copyWith(phase: ClaimPhase.error, errorMessage: msg);
      notifyListeners();
      return null;
    }
  }

  void clear(String key) {
    icLogger.i('[claim] clear key=$key');
    _byPda.remove(key);
    _builtByPda.remove(key);
    notifyListeners();
  }

  void clearAll() {
    icLogger.i('[claim] clearAll');
    _byPda.clear();
    _builtByPda.clear();
    notifyListeners();
  }
}

String _friendlyClaimError(Object e) {
  final s = e.toString();
  if (s.contains('not eligible')) return 'Not eligible for this claim.';
  if (s.contains('already claimed')) return 'This claim was already completed.';
  if (s.contains('game not resolved')) return 'Game is not resolved yet. Try again shortly.';
  if (s.contains('resolved game not found')) return 'Results aren\'t available yet. Try again shortly.';
  if (s.contains('invalid merkle proof')) return 'Claim data mismatch. Please refresh and try again.';
  if (s.toLowerCase().contains('blockhash')) return 'Network delay. Please try again.';
  return s;
}
