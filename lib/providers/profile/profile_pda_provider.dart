// lib/providers/profile_pda_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:iseefortune_flutter/models/profile/profile_pda_model.dart';
import 'package:iseefortune_flutter/services/profile/profile_pda_service.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

class ProfilePdaProvider extends ChangeNotifier {
  ProfilePdaProvider({required ProfilePdaService service}) : _service = service;

  final ProfilePdaService _service;

  WalletConnectionProvider? _walletConn;
  VoidCallback? _walletListener;

  StreamSubscription<PlayerProfilePDAModel>? _sub;

  PlayerProfilePDAModel? _profile;
  bool _isLoading = false;
  Object? _lastError;

  bool _disposed = false;
  String? _walletPubkey;

  bool _hasLoadedOnce = false;
  bool get hasLoadedOnce => _hasLoadedOnce;

  PlayerProfilePDAModel? get profile => _profile;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  int get changeTickets => _profile?.ticketsAvailable ?? 0;
  bool get hasChangeTickets => changeTickets > 0;

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  void attachWalletConnection(WalletConnectionProvider walletConn) {
    //icLogger.i('[ProfilePdaProvider] attachWalletConnection initial=${walletConn.pubkey}');

    if (_walletConn != null && _walletListener != null) {
      _walletConn!.removeListener(_walletListener!);
    }

    _walletConn = walletConn;
    _walletListener = () => _handleWalletChanged(_walletConn!.pubkey);

    _walletConn!.addListener(_walletListener!);
    _handleWalletChanged(_walletConn!.pubkey);
  }

  void _handleWalletChanged(String? nextPubkey) {
    if (_walletPubkey == nextPubkey) return;

    //icLogger.i('[ProfilePdaProvider] wallet pubkey changed -> $nextPubkey');
    _walletPubkey = nextPubkey;

    if (nextPubkey == null) {
      unawaited(stop());
      return;
    }

    unawaited(start(nextPubkey));
  }

  /// Mechanism A:
  /// - Always subscribe to the profile PDA stream, even if the account doesn't exist yet.
  /// - This lets us catch the moment a brand-new profile is created by `place_prediction`.
  Future<void> start(String walletPubkey) async {
    // Cancel any previous subscription (switch wallet safety)
    await _sub?.cancel();
    _sub = null;

    _isLoading = true;
    _hasLoadedOnce = false;
    _lastError = null;
    _profile = null;
    _safeNotify();

    try {
      final snap = await _service.fetchProfileByWalletPubkey(walletPubkey, commitment: 'confirmed');

      _hasLoadedOnce = true;
      if (_walletPubkey != walletPubkey) return;

      // If snap is null, that's fine: it means the profile PDA doesn't exist YET.
      // We'll still subscribe below so we can detect when it gets created.
      _profile = snap;
      _isLoading = false;
      _lastError = null;
      _safeNotify();

      // Always subscribe, even if snap == null previously.
      // Fixes brand-new players not updating live.
      _sub = _service
          .subscribeProfileByWalletPubkey(walletPubkey, commitment: 'confirmed')
          .listen(
            (p) {
              if (_walletPubkey != walletPubkey) return;

              icLogger.i(
                '[ProfilePdaProvider] profile update: recentBetsLen=${p.recentBets.length} '
                'lastPlayedEpoch=${p.lastPlayedEpoch} ts=${p.lastPlayedTimestamp}',
              );

              _profile = p;
              _safeNotify();
            },
            onError: (e) {
              if (_walletPubkey != walletPubkey) return;
              _lastError = e;
              _safeNotify();
            },
          );
    } catch (e) {
      if (_walletPubkey != walletPubkey) return;
      _lastError = e;
      _hasLoadedOnce = true;
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> stop() async {
    final s = _sub;
    _sub = null;
    if (s != null) await s.cancel();

    _profile = null;
    _isLoading = false;
    _lastError = null;

    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;

    if (_walletConn != null && _walletListener != null) {
      _walletConn!.removeListener(_walletListener!);
    }

    _sub?.cancel();
    _sub = null;

    super.dispose();
  }

  /// Mechanism B:
  /// Force a one-shot pull from RPC.
  /// Call this after a confirmed transaction that you know updated the profile.
  Future<void> refetchNow({String commitment = 'confirmed'}) async {
    final walletPubkey = _walletPubkey;
    if (walletPubkey == null) return;

    try {
      final snap = await _service.fetchProfileByWalletPubkey(walletPubkey, commitment: commitment);
      if (_walletPubkey != walletPubkey) return;

      // If it exists now (e.g. first bet created it), adopt it immediately.
      if (snap != null) {
        _profile = snap;
        _lastError = null;
        _hasLoadedOnce = true;
        _safeNotify();
      }
    } catch (e) {
      _lastError = e;
      _safeNotify();
    }
  }
}
