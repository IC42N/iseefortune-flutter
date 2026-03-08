import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:solana/base58.dart' show base58decode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iseefortune_flutter/solana/wallet/wallet_adapter_services.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:solana_seed_vault/solana_seed_vault.dart';

enum WalletKind { mwa, seedVault }

extension WalletKindStorage on WalletKind {
  String get storageValue => this == WalletKind.mwa ? 'mwa' : 'seed_vault';

  static WalletKind? fromStorage(String? v) {
    if (v == 'mwa') return WalletKind.mwa;
    if (v == 'seed_vault') return WalletKind.seedVault;
    return null;
  }
}

class WalletConnectError {
  WalletConnectError(this.title, this.message, {this.debug});
  final String title;
  final String message;
  final String? debug;

  @override
  String toString() => '$title: $message';
}

/// A small “snapshot” of the current connected wallet lane + required signing metadata.
sealed class WalletSession {
  const WalletSession({required this.kind, required this.pubkey});
  final WalletKind kind;
  final String pubkey;
}

class MwaWalletSession extends WalletSession {
  const MwaWalletSession({required super.pubkey, required this.authToken}) : super(kind: WalletKind.mwa);
  final String authToken;
}

class SeedVaultWalletSession extends WalletSession {
  const SeedVaultWalletSession({
    required super.pubkey,
    required this.authToken,
    required this.accountId,
    required this.derivationPath,
  }) : super(kind: WalletKind.seedVault);

  final int authToken;
  final int accountId;
  final Uri derivationPath;
}

class WalletConnectionProvider extends ChangeNotifier {
  WalletConnectionProvider({required SolanaWalletAdapterService mwa, FlutterSecureStorage? storage})
    : _mwa = mwa,
      _storage = storage ?? const FlutterSecureStorage();

  final SolanaWalletAdapterService _mwa;
  final FlutterSecureStorage _storage;

  // Storage keys
  static const _kWalletKind = 'wallet_kind';
  static const _kMWAPubkey = 'mwa_pubkey_b58';

  // MWA
  static const _kMwaAuthToken = 'mwa_auth_token';

  // Seed Vault
  static const _kSeedVaultPubkey = 'seed_vault_pubkey_b58';
  static const _kSeedVaultAuthToken = 'seed_vault_auth_token';
  static const _kSeedVaultAccountId = 'seed_vault_account_id';
  static const _kSeedVaultDerivationPath = 'seed_vault_derivation_path';

  WalletKind? _kind;
  String? _pubkey;

  // MWA in-memory
  String? _mwaAuthToken;

  // Seed Vault in-memory
  int? _seedVaultAuthToken;
  int? _seedVaultAccountId;
  Uri? _seedVaultDerivationPath;

  bool _isConnecting = false;
  bool _isDisconnecting = false;

  Object? _lastError;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  WalletKind? get kind => _kind;
  String? get pubkey => _pubkey;

  bool get isConnecting => _isConnecting; // only connect flows
  bool get isDisconnecting => _isDisconnecting;
  bool get isBusy => _isConnecting || _isDisconnecting;
  bool get isConnected => _pubkey != null;
  Object? get lastError => _lastError;

  WalletConnectError? get uiError =>
      _lastError is WalletConnectError ? _lastError as WalletConnectError : null;

  String? get mwaAuthToken => _mwaAuthToken;
  String? get mwaAddressB58 => (_kind == WalletKind.mwa) ? _pubkey : null;
  int? get seedVaultAuthToken => _seedVaultAuthToken;
  int? get seedVaultAccountId => _seedVaultAccountId;
  Uri? get seedVaultDerivationPath => _seedVaultDerivationPath;

  WalletSession? get session {
    final k = _kind;
    final pk = _pubkey;
    if (k == null || pk == null) return null;

    switch (k) {
      case WalletKind.mwa:
        final t = _mwaAuthToken;
        if (t == null || t.isEmpty) return null;
        return MwaWalletSession(pubkey: pk, authToken: t);

      case WalletKind.seedVault:
        final a = _seedVaultAuthToken;
        final id = _seedVaultAccountId;
        final dp = _seedVaultDerivationPath;
        if (a == null || id == null || dp == null) return null;
        return SeedVaultWalletSession(pubkey: pk, authToken: a, accountId: id, derivationPath: dp);
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  WalletConnectError _mapConnectError(Object e) {
    final raw = e.toString();

    if (raw.contains('ActivityNotFoundException') ||
        raw.contains('No Activity found to handle Intent') ||
        raw.contains('solana-wallet:')) {
      return WalletConnectError(
        'No wallet app found',
        'Install a Solana wallet that supports Mobile Wallet Adapter (MWA) (ex: Phantom, Backpack) and try again.',
        debug: raw,
      );
    }

    return WalletConnectError(
      'Wallet connection failed',
      'Something went wrong while connecting. Please try again.',
      debug: raw,
    );
  }

  // ---------------------------------------------------------------------------
  // Auto restore (best effort)
  // ---------------------------------------------------------------------------

  Future<void> tryAutoConnect() async {
    if (_isConnecting) return;

    icLogger.i('[WalletConnection] tryAutoConnect called');
    icLogger.i('[WalletConnection] pubkey=$_pubkey kind=$_kind canSign=${session != null}');

    final savedKindStr = await _storage.read(key: _kWalletKind);
    final savedKind = WalletKindStorage.fromStorage(savedKindStr);
    if (savedKind == null) return;

    final savedPubkey = switch (savedKind) {
      WalletKind.mwa => await _storage.read(key: _kMWAPubkey),
      WalletKind.seedVault => await _storage.read(key: _kSeedVaultPubkey),
    };

    // optimistic UI
    if (savedPubkey != null && savedPubkey.isNotEmpty) {
      _pubkey = savedPubkey;
      _kind = savedKind;
      notifyListeners();
    }

    icLogger.i(
      '[WalletConnection] after optimistic restore pubkey=$_pubkey kind=$_kind canSign=${session != null}',
    );

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      switch (savedKind) {
        case WalletKind.mwa:
          final savedMwaToken = await _storage.read(key: _kMwaAuthToken);
          final savedMwaPubkey = await _storage.read(key: _kMWAPubkey);

          if (savedMwaPubkey == null || savedMwaPubkey.isEmpty) {
            await _clearPersisted();
            _resetInMemory();
            return;
          }

          // Only restore UI state (NOT signing capability)
          _kind = WalletKind.mwa;
          _pubkey = savedMwaPubkey;
          _mwaAuthToken = savedMwaToken;

          if (savedMwaToken != null && savedMwaToken.isNotEmpty) {
            final pkBytes = Uint8List.fromList(base58decode(savedMwaPubkey));
            if (pkBytes.length == 32) {
              _mwa.restoreLocalSession(
                authToken: savedMwaToken,
                activeAddressB58: savedMwaPubkey,
                activePubkeyBytes: pkBytes,
              );
            }
          }

          notifyListeners();
          return;

        case WalletKind.seedVault:
          final ok = await _tryRestoreSeedVault();
          if (!ok) {
            _clearSeedVaultSigningOnlyMemory();
            notifyListeners();
          }
          return;
      }
    } catch (e) {
      if (savedKind == WalletKind.mwa) {
        _lastError = _mapConnectError(e);
        if (kDebugMode) {
          icLogger.w('[WalletConnection] autoconnect failed: ${uiError?.debug ?? e}');
        } else {
          icLogger.w('[WalletConnection] autoconnect failed');
        }
      } else {
        // SeedVault boot failures are expected; do NOT delete persisted token.
        icLogger.i('[WalletConnection] SeedVault autoconnect failed (expected): $e');
        _clearSeedVaultSigningOnlyMemory();
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // User-initiated MWA connect
  // ---------------------------------------------------------------------------

  Future<void> connect(BuildContext context) async {
    if (_isConnecting) return;

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      // SolanaWalletAdapterService handles initIdentity internally via init()
      icLogger.i('[MWA] starting authorize()');
      final res = await _mwa.authorize();
      icLogger.i('[MWA] authorize() done res=${res != null}');

      if (res == null) {
        _lastError = WalletConnectError('Cancelled', 'Wallet connection was cancelled.');
        return;
      }

      _kind = WalletKind.mwa;
      _mwaAuthToken = res.authToken;
      _pubkey = res.addressB58;

      await _storage.write(key: _kWalletKind, value: _kind!.storageValue);
      await _storage.write(key: _kMwaAuthToken, value: _mwaAuthToken);
      await _storage.write(key: _kMWAPubkey, value: _pubkey);
    } catch (e, st) {
      icLogger.e('[MWA] connect error: $e\n$st');
      _lastError = (e is WalletConnectError) ? e : _mapConnectError(e);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // User-initiated Seed Vault connect
  // ---------------------------------------------------------------------------
  Future<void> connectSeedVault() async {
    if (_isConnecting) return;

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    void log(String msg) => icLogger.i('[SeedVault][connect] $msg');
    void warn(String msg) => icLogger.w('[SeedVault][connect] $msg');

    try {
      final seedVault = SeedVault.instance;

      final available = await seedVault.isAvailable(allowSimulated: true);
      if (!available) {
        throw WalletConnectError('Seed Vault unavailable', 'Seed Vault is not available on this device.');
      }

      final hasPerm = await seedVault.checkPermission();
      if (!hasPerm) {
        warn('checkPermission() == false (continuing anyway)');
      }

      // -----------------------------------------------------------------------
      // Read what we previously pinned to (if anything)
      // -----------------------------------------------------------------------
      final savedPubkey = await _storage.read(key: _kSeedVaultPubkey);
      final savedIdStr = await _storage.read(key: _kSeedVaultAccountId);
      final savedId = int.tryParse(savedIdStr ?? '');
      final savedDpStr = await _storage.read(key: _kSeedVaultDerivationPath);

      log('saved pin: savedId=$savedId savedPubkey=$savedPubkey savedDp=$savedDpStr');

      // -----------------------------------------------------------------------
      // 1) Silent restore/pin first (NO UI)
      //    - This prevents "random" changes when multiple seeds/accounts exist.
      // -----------------------------------------------------------------------
      final ok = await _tryRestoreSeedVault();
      if (ok) {
        log(
          'silent restore OK: pinned acct=$_seedVaultAccountId pubkey=$_pubkey dp=$_seedVaultDerivationPath',
        );

        // Persist wallet kind + pubkey to ensure UI + app state stays correct.
        await _storage.write(key: _kWalletKind, value: WalletKind.seedVault.storageValue);
        await _storage.write(key: _kSeedVaultPubkey, value: _pubkey);

        // Switching lanes
        _mwaAuthToken = null;
        await _storage.delete(key: _kMwaAuthToken);

        notifyListeners();
        return;
      } else {
        log('silent restore failed (expected on some boots). Will try other authorized seed sessions…');
      }

      // -----------------------------------------------------------------------
      // 2) Try other already-authorized seed sessions (NO UI)
      //    - If multiple auth tokens exist, pick the one matching saved pubkey/id.
      // -----------------------------------------------------------------------
      final match = await _findMatchingAuthorizedSeedSession();
      if (match != null) {
        final token = match.$1;
        final acct = match.$2;

        log(
          'matched authorized seed session: token=$token acctId=${acct.id} pk=${acct.publicKeyEncoded} dp=${acct.derivationPath}',
        );

        await _commitSeedVaultSession(token, acct);

        // Switching lanes
        _mwaAuthToken = null;
        await _storage.delete(key: _kMwaAuthToken);

        log(
          'committed matched session: acct=$_seedVaultAccountId pubkey=$_pubkey dp=$_seedVaultDerivationPath',
        );
        return;
      } else {
        log('no matching authorized seed session found. Falling back to interactive authorize…');
      }

      // -----------------------------------------------------------------------
      // 3) Last resort: interactive authorization
      // -----------------------------------------------------------------------
      const purpose = Purpose.signSolanaTransaction;

      final AuthToken newToken;
      try {
        newToken = await seedVault.authorizeSeed(purpose);
      } catch (e) {
        final raw = e.toString();
        if (raw.contains('result=0')) {
          _lastError = WalletConnectError(
            'Authorization cancelled',
            'Seed Vault authorization was cancelled. Try again when you’re ready.',
            debug: raw,
          );
          log('authorizeSeed cancelled: $raw');
          return;
        }
        rethrow;
      }

      final accounts = await seedVault.getParsedAccounts(newToken);
      if (accounts.isEmpty) {
        throw WalletConnectError('No accounts found', 'Seed Vault returned no accounts.');
      }

      log('interactive token=$newToken accounts=${accounts.length}');
      for (final a in accounts) {
        log('acct: id=${a.id} user=${a.isUserWallet} pk=${a.publicKeyEncoded} dp=${a.derivationPath}');
      }

      // -----------------------------------------------------------------------
      // Deterministic selection:
      //   1) saved accountId
      //   2) saved pubkey
      //   3) default Solana path (best-effort)
      //   4) isUserWallet
      //   5) first
      // -----------------------------------------------------------------------
      Account? chosen;

      bool looksLikeDefaultSolanaPath(Uri dp) {
        final s = dp.toString();
        return s.contains("44'/501'/0'") ||
            s.contains("m/44'/501'/0'") ||
            s.contains("/44'/501'/0'") ||
            s.contains("44%27/501%27/0%27");
      }

      // (1) saved accountId
      if (savedId != null) {
        chosen = firstWhereOrNull(accounts, (a) => a.id == savedId);
        if (chosen != null) log('choose: matched savedId=$savedId');
      }

      // (2) saved pubkey
      if (chosen == null && savedPubkey != null && savedPubkey.isNotEmpty) {
        chosen = firstWhereOrNull(accounts, (a) => a.publicKeyEncoded == savedPubkey);
        if (chosen != null) log('choose: matched savedPubkey=$savedPubkey');
      }

      // (3) isUserWallet FIRST
      chosen ??= firstWhereOrNull(accounts, (a) => a.isUserWallet == true);
      if (chosen != null && chosen.isUserWallet == true) {
        log('choose: matched isUserWallet acctId=${chosen.id}');
      }

      // (4) default Solana derivation path SECOND (only if still null)
      if (chosen == null) {
        chosen = firstWhereOrNull(accounts, (a) => looksLikeDefaultSolanaPath(a.derivationPath));
        if (chosen != null) {
          log('choose: matched default Solana derivation path dp=${chosen.derivationPath}');
        }
      }

      // (5) first
      chosen ??= accounts.first;

      log(
        'choose: final acctId=${chosen.id} pk=${chosen.publicKeyEncoded} dp=${chosen.derivationPath} user=${chosen.isUserWallet}',
      );

      await _commitSeedVaultSession(newToken, chosen);
      _mwaAuthToken = null;
      await _storage.delete(key: _kMwaAuthToken);

      log('connected+persisted: pubkey=$_pubkey acct=$_seedVaultAccountId dp=$_seedVaultDerivationPath');
    } catch (e) {
      _lastError = (e is WalletConnectError)
          ? e
          : WalletConnectError(
              'Seed Vault connection failed',
              'Unable to connect to Seed Vault. Please try again.',
              debug: e.toString(),
            );
      warn(
        'failed: ${_lastError is WalletConnectError ? (_lastError as WalletConnectError).debug : e.toString()}',
      );
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Seed Vault restore (no getParsedAccount-by-id)
  // ---------------------------------------------------------------------------

  Future<bool> _tryRestoreSeedVault() async {
    try {
      final seedVault = SeedVault.instance;

      final available = await seedVault.isAvailable(allowSimulated: true);
      if (!available) return false;

      final tokenStr = await _storage.read(key: _kSeedVaultAuthToken);
      final token = _parseAuthToken(tokenStr);
      if (token == null) return false;

      final accounts = await seedVault.getParsedAccounts(token);
      if (accounts.isEmpty) return false;

      final savedIdStr = await _storage.read(key: _kSeedVaultAccountId);
      final savedId = int.tryParse(savedIdStr ?? '');

      final chosen = (savedId != null)
          ? accounts.firstWhere(
              (a) => a.id == savedId,
              orElse: () => accounts.firstWhere((a) => a.isUserWallet == true, orElse: () => accounts.first),
            )
          : accounts.firstWhere((a) => a.isUserWallet == true, orElse: () => accounts.first);

      _kind = WalletKind.seedVault;
      _pubkey = chosen.publicKeyEncoded;
      await _storage.write(key: _kSeedVaultPubkey, value: _pubkey);

      _mwaAuthToken = null;
      _seedVaultAuthToken = token;
      _seedVaultAccountId = chosen.id;
      _seedVaultDerivationPath = chosen.derivationPath;

      notifyListeners();
      return true;
    } catch (e) {
      icLogger.i('[WalletConnection] _tryRestoreSeedVault (expected) failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Seed Vault signing-session bootstrap (silent-first)
  // ---------------------------------------------------------------------------

  Future<SeedVaultWalletSession> ensureSeedVaultSessionForSigning() async {
    final seedVault = SeedVault.instance;
    const purpose = Purpose.signSolanaTransaction;

    final available = await seedVault.isAvailable(allowSimulated: true);
    if (!available) {
      throw WalletConnectError('Seed Vault unavailable', 'Seed Vault is not available on this device.');
    }

    // 1) Try in-memory token
    final mem = _seedVaultAuthToken;
    if (mem != null) {
      final accounts = await _tryAccountsForToken(mem);
      if (accounts != null) {
        final chosen = _chooseAccountFromAccounts(accounts);
        return await _commitSeedVaultSession(mem, chosen);
      }
    }

    // 2) Try persisted token
    final persistedStr = await _storage.read(key: _kSeedVaultAuthToken);
    final persisted = _parseAuthToken(persistedStr);
    if (persisted != null) {
      final accounts = await _tryAccountsForToken(persisted);
      if (accounts != null) {
        final chosen = _chooseAccountFromAccounts(accounts);
        return await _commitSeedVaultSession(persisted, chosen);
      }
    }

    // 3) Try already-authorized seed tokens (NO UI)
    final match = await _findMatchingAuthorizedSeedSession();
    if (match != null) {
      final token = match.$1;
      final acct = match.$2;
      return await _commitSeedVaultSession(token, acct);
    }

    // 4) Last resort: interactive
    try {
      final newToken = await seedVault.authorizeSeed(purpose);
      final accounts = await seedVault.getParsedAccounts(newToken);
      if (accounts.isEmpty) {
        throw WalletConnectError('Seed Vault has no accounts', 'No accounts were found in Seed Vault.');
      }
      final chosen = _chooseAccountFromAccounts(accounts);
      return await _commitSeedVaultSession(newToken, chosen);
    } catch (e) {
      throw WalletConnectError(
        'Seed Vault locked',
        'Unlock Seed Vault to sign this transaction.',
        debug: e.toString(),
      );
    }
  }

  // These accounts are dynamic from the plugin; keep this untyped.
  Future<List<dynamic>?> _tryAccountsForToken(int token) async {
    try {
      final accounts = await SeedVault.instance.getParsedAccounts(token);
      return accounts.isEmpty ? null : accounts;
    } catch (_) {
      return null;
    }
  }

  dynamic _chooseAccountFromAccounts(List<dynamic> accounts) {
    final savedId = _seedVaultAccountId;
    if (savedId != null) {
      for (final a in accounts) {
        if (a.id == savedId) return a;
      }
    }
    for (final a in accounts) {
      if (a.isUserWallet == true) return a;
    }
    return accounts.first;
  }

  Future<SeedVaultWalletSession> _commitSeedVaultSession(int token, dynamic chosen) async {
    final dp = chosen.derivationPath as Uri;

    _kind = WalletKind.seedVault;
    _pubkey = chosen.publicKeyEncoded as String?;
    _seedVaultAuthToken = token;
    _seedVaultAccountId = chosen.id as int?;
    _seedVaultDerivationPath = dp;

    await _storage.write(key: _kWalletKind, value: _kind!.storageValue);
    await _storage.write(key: _kSeedVaultPubkey, value: _pubkey);
    await _storage.write(key: _kSeedVaultAuthToken, value: token.toString());
    final id = chosen.id as int?;
    _seedVaultAccountId = id;

    if (id == null || id <= 0) {
      await _storage.delete(key: _kSeedVaultAccountId);
    } else {
      await _storage.write(key: _kSeedVaultAccountId, value: id.toString());
    }
    await _storage.write(key: _kSeedVaultDerivationPath, value: dp.toString());

    notifyListeners();

    return SeedVaultWalletSession(
      pubkey: _pubkey!,
      authToken: token,
      accountId: _seedVaultAccountId!,
      derivationPath: dp,
    );
  }

  Future<List<int>> _getAuthorizedSeedTokens() async {
    try {
      final cursor = await SeedVault.instance.getAuthorizedSeeds();

      final out = <int>[];
      for (final row in cursor) {
        final dynamic v = row['AuthorizedSeeds_AuthToken'];
        if (v is int) {
          out.add(v);
        } else if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) out.add(parsed);
        } else if (v != null) {
          final m = RegExp(r'(\d+)').firstMatch(v.toString());
          final parsed = m == null ? null : int.tryParse(m.group(1)!);
          if (parsed != null) out.add(parsed);
        }
      }
      return out;
    } catch (e) {
      icLogger.i('[WalletConnection] getAuthorizedSeeds failed (expected sometimes): $e');
      return const [];
    }
  }

  Future<(int, dynamic)?> _findMatchingAuthorizedSeedSession() async {
    // Only trust in-memory pubkey if we are already in Seed Vault lane.
    final memPk = (_kind == WalletKind.seedVault) ? _pubkey : null;
    final savedPk = memPk ?? await _storage.read(key: _kSeedVaultPubkey);

    final savedIdStr = await _storage.read(key: _kSeedVaultAccountId);
    final parsedId = int.tryParse(savedIdStr ?? '');

    // Treat 0 / negative as "not pinned"
    final int? savedId = (parsedId != null && parsedId > 0) ? parsedId : null;

    final tokens = await _getAuthorizedSeedTokens();
    if (tokens.isEmpty) return null;

    for (final t in tokens) {
      final accounts = await _tryAccountsForToken(t);
      if (accounts == null || accounts.isEmpty) continue;

      // 1) Prefer matching by accountId (ONLY if it's a real pinned id)
      if (savedId != null) {
        for (final a in accounts) {
          final int? id = a.id as int?;
          if (id != null && id == savedId) return (t, a);
        }
      }

      // 2) Then match by pubkey
      if (savedPk != null && savedPk.isNotEmpty) {
        for (final a in accounts) {
          final String? pk = a.publicKeyEncoded as String?;
          if (pk != null && pk == savedPk) return (t, a);
        }
      }
    }

    return null;
  }

  // in WalletConnectionProvider
  void cancelConnectAttempt({String reason = 'cancelled'}) {
    if (!_isConnecting) return;

    icLogger.i('[WalletConnection] cancelConnectAttempt: $reason');

    // If you add cancelActiveSession() to your MWA service, call it here:
    // _mwa.cancelActiveSession();

    _isConnecting = false;
    _lastError = WalletConnectError('Cancelled', 'Connection cancelled.');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  // In WalletConnectionProvider
  // Future<void> refreshMwaSessionForSigning() async {
  //   final t = _mwaAuthToken ?? await _storage.read(key: _kMwaAuthToken);
  //   final pkB58 = (_kind == WalletKind.mwa ? _pubkey : null) ?? await _storage.read(key: _kMWAPubkey);

  //   if (t == null || t.isEmpty) {
  //     throw WalletConnectError('Not connected', 'Connect wallet first.');
  //   }
  //   if (pkB58 == null || pkB58.isEmpty) {
  //     throw WalletConnectError('Not connected', 'Connect wallet first.');
  //   }

  //   // Restore into the Kotlin-backed service (non-interactive)
  //   await _mwa.restoreSession(authTokenB64: t, activeAddressB58: pkB58);

  //   // Keep provider state consistent
  //   _kind = WalletKind.mwa;
  //   _mwaAuthToken = t;
  //   _pubkey = pkB58;

  //   notifyListeners();
  // }

  Future<void> ensureMwaConnectedForSigning() async {
    final savedToken = _mwaAuthToken ?? await _storage.read(key: _kMwaAuthToken);
    final savedPubkey = (_kind == WalletKind.mwa ? _pubkey : null) ?? await _storage.read(key: _kMWAPubkey);

    if (savedToken != null && savedToken.isNotEmpty && savedPubkey != null && savedPubkey.isNotEmpty) {
      final pkBytes = Uint8List.fromList(base58decode(savedPubkey));
      if (pkBytes.length != 32) {
        throw WalletConnectError(
          'Wallet session invalid',
          'Stored MWA public key is invalid. Please reconnect wallet.',
        );
      }

      _kind = WalletKind.mwa;
      _mwaAuthToken = savedToken;
      _pubkey = savedPubkey;

      _mwa.restoreLocalSession(
        authToken: savedToken,
        activeAddressB58: savedPubkey,
        activePubkeyBytes: pkBytes,
      );

      notifyListeners();
      return;
    }

    final res = await _mwa.authorize();
    if (res == null) {
      throw WalletConnectError('Cancelled', 'Wallet connection was cancelled.');
    }

    _kind = WalletKind.mwa;
    _mwaAuthToken = res.authToken;
    _pubkey = res.addressB58;

    await _storage.write(key: _kWalletKind, value: _kind!.storageValue);
    await _storage.write(key: _kMwaAuthToken, value: _mwaAuthToken);
    await _storage.write(key: _kMWAPubkey, value: _pubkey);

    notifyListeners();
  }

  void _clearSeedVaultSigningOnlyMemory() {
    _seedVaultAuthToken = null;
    _seedVaultDerivationPath = null;
    // keep accountId + pubkey/kind
  }

  Future<void> disconnect({bool revoke = false}) async {
    if (_isConnecting || _isDisconnecting) return;

    final kind = _kind;
    final seedTokenStr = await _storage.read(key: _kSeedVaultAuthToken);
    final seedAuthToken = _parseAuthToken(seedTokenStr);

    _isDisconnecting = true;
    _lastError = null;

    // Reset UI immediately
    _resetInMemory();
    notifyListeners();

    try {
      await _clearPersisted();

      if (kind == WalletKind.mwa) {
        // IMPORTANT: always clear native MWA session state
        await _mwa.deauthorize(interactive: revoke);

        // Give wallet/session teardown a brief moment before another connect
        await Future.delayed(const Duration(milliseconds: 800));
      } else if (kind == WalletKind.seedVault) {
        if (revoke && seedAuthToken != null) {
          await SeedVault.instance.deauthorizeSeed(seedAuthToken);
        }
      }
    } catch (e) {
      icLogger.w('[WalletConnection] disconnect failed: $e');
      _lastError = e;
    } finally {
      _isDisconnecting = false;
      notifyListeners();
    }
  }

  Future<void> _clearPersisted() async {
    await _storage.delete(key: _kWalletKind);
    await _storage.delete(key: _kSeedVaultPubkey);
    await _storage.delete(key: _kMWAPubkey);
    await _storage.delete(key: _kMwaAuthToken);
    await _storage.delete(key: _kSeedVaultAuthToken);
    await _storage.delete(key: _kSeedVaultAccountId);
    await _storage.delete(key: _kSeedVaultDerivationPath);
  }

  void _resetInMemory() {
    _pubkey = null;
    _kind = null;

    _mwaAuthToken = null;

    _seedVaultAuthToken = null;
    _seedVaultAccountId = null;
    _seedVaultDerivationPath = null;
  }

  int? _parseAuthToken(String? s) {
    if (s == null) return null;
    final direct = int.tryParse(s);
    if (direct != null) return direct;

    final m = RegExp(r'(\d+)').firstMatch(s);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  T? firstWhereOrNull<T>(List<T> list, bool Function(T a) test) {
    for (final a in list) {
      if (test(a)) return a;
    }
    return null;
  }
}
