import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:iseefortune_flutter/providers/price_provider.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/solana/wallet_balance_stream.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:iseefortune_flutter/utils/solana/lamports.dart';

/// WalletProvider (IC42N)
/// ---------------------------------------------------------------------------
/// Owns *the currently connected wallet* state:
/// - pubkey (null when disconnected)
/// - lamports (null until first value arrives)
/// - isLoading (true while fetching/streaming first value)
/// - derived balances: SOL + USD
///
/// It does NOT manage multiple wallets/burners.
/// The external wallet (Phantom/Backpack/etc) is the source of truth.
class WalletProvider extends ChangeNotifier {
  WalletProvider({required WalletBalanceStream balanceStream, PriceProvider? priceProvider})
    : _balanceStream = balanceStream {
    if (priceProvider != null) attachPriceProvider(priceProvider);
  }

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final WalletBalanceStream _balanceStream;

  PriceProvider? _priceProvider;
  VoidCallback? _priceListener;

  WalletConnectionProvider? _walletConn;
  VoidCallback? _walletConnListener;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String? _pubkey;
  int? _lamports;
  bool _isLoading = false;

  StreamSubscription<int>? _balanceSub;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  String? get pubkey => _pubkey;
  int? get lamports => _lamports;

  bool get isConnected => _pubkey != null;

  /// Null SOL balance until we have lamports; avoids UI briefly showing "0".
  double? get solBalance => _lamports == null ? null : _lamports! / 1e9;
  String get solBalanceText => lamportsToSolText(BigInt.from(_lamports ?? 0));

  /// Null USD balance until we have lamports (and price if you want).
  double? get usdBalance {
    final sol = solBalance;
    if (sol == null) return null;
    return sol * (_priceProvider?.solUsd ?? 0);
  }

  bool get isLoading => _isLoading;

  // ---------------------------------------------------------------------------
  // Attach price provider (for USD conversion)
  // ---------------------------------------------------------------------------

  void attachPriceProvider(PriceProvider priceProvider) {
    // Detach from prior provider (if any)
    if (_priceProvider != null && _priceListener != null) {
      _priceProvider!.removeListener(_priceListener!);
    }

    _priceProvider = priceProvider;
    _priceListener = () {
      // Price update => USD changes (lamports doesn't need to change)
      notifyListeners();
    };

    _priceProvider!.addListener(_priceListener!);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Attach wallet connection provider (pubkey source of truth)
  // ---------------------------------------------------------------------------

  void attachWalletConnection(WalletConnectionProvider walletConn) {
    // Detach previous listener if re-attaching
    if (_walletConn != null && _walletConnListener != null) {
      _walletConn!.removeListener(_walletConnListener!);
    }

    _walletConn = walletConn;
    _walletConnListener = () {
      // Wallet adapter changed pubkey (connect, disconnect, or switch account)
      _handleWalletPubkeyChange(_walletConn!.pubkey);
    };

    _walletConn!.addListener(_walletConnListener!);

    // Initial bind for first render
    _handleWalletPubkeyChange(_walletConn!.pubkey);
  }

  // ---------------------------------------------------------------------------
  // Internal: handle connect/disconnect/switch
  // ---------------------------------------------------------------------------

  void _handleWalletPubkeyChange(String? nextPubkey) {
    // If the pubkey didn't change, do nothing
    if (_pubkey == nextPubkey) return;

    icLogger.i('[WalletProvider] pubkey changed -> $nextPubkey');

    // Connected
    if (nextPubkey != null) {
      _setConnectedPubkey(nextPubkey);
      return;
    }

    // Disconnected
    _clearWalletState();
  }

  void _setConnectedPubkey(String pubkey) {
    // Fire and forget async; we don’t want caller to await.
    unawaited(_startStreaming(pubkey));
  }

  Future<void> _startStreaming(String pubkey) async {
    // Cancel old stream subscription first
    await _balanceSub?.cancel();
    _balanceSub = null;

    // Reset state so UI doesn't show stale numbers
    _pubkey = pubkey;
    _lamports = null;
    _isLoading = true;
    notifyListeners();

    // Tiny delay is optional but helps avoid weird UI races during wallet switching
    await Future.delayed(const Duration(milliseconds: 50));

    _balanceSub = _balanceStream.watch(pubkey).listen((lamps) {
      if (lamps != _lamports) {
        _lamports = lamps;
        if (_isLoading) _isLoading = false;
        notifyListeners();
      }
    });
  }

  void _clearWalletState() {
    // Cancel stream subscription
    _balanceSub?.cancel();
    _balanceSub = null;

    // Stop underlying WS/poll timers
    _balanceStream.stop();

    // Clear exposed state
    _pubkey = null;
    _lamports = null;
    _isLoading = false;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Public: manual refresh
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    final key = _pubkey;
    if (key != null) {
      await _balanceStream.refresh(key);
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    if (_priceProvider != null && _priceListener != null) {
      _priceProvider!.removeListener(_priceListener!);
    }
    if (_walletConn != null && _walletConnListener != null) {
      _walletConn!.removeListener(_walletConnListener!);
    }

    _balanceSub?.cancel();
    _balanceStream.stop();

    super.dispose();
  }
}
