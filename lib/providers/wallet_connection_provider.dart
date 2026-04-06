import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iseefortune_flutter/solana/wallet/wallet_adapter_services.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:solana/base58.dart' show base58decode;
import 'package:solana_seed_vault/solana_seed_vault.dart';

enum WalletKind { mwa, seedVault }

extension WalletKindStorage on WalletKind {
  String get storageValue => this == WalletKind.mwa ? 'mwa' : 'seed_vault';

  static WalletKind? fromStorage(String? value) {
    if (value == 'mwa') return WalletKind.mwa;
    if (value == 'seed_vault') return WalletKind.seedVault;
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

/// Snapshot of the currently connected wallet lane plus whatever metadata is
/// required later for signing.
///
/// - MWA uses a string auth token.
/// - Seed Vault uses an integer auth token + account metadata.
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

/// Owns wallet connection state for both supported lanes:
/// - MWA
/// - Solana Seed Vault
///
/// Responsibilities:
/// - connect/disconnect
/// - session persistence
/// - best-effort restore on app launch
/// - provide enough session metadata for later signing flows
///
/// Important Seed Vault note:
/// Disconnecting with revoke=true intentionally deauthorizes currently
/// authorized Seed Vault rows, then waits briefly for the provider to settle
/// before clearing local state. Without that settle delay, immediate reconnects
/// can fail even after a successful deauthorization.
class WalletConnectionProvider extends ChangeNotifier {
  WalletConnectionProvider({required SolanaWalletAdapterService mwa, FlutterSecureStorage? storage})
    : _mwa = mwa,
      _storage = storage ?? const FlutterSecureStorage();

  final SolanaWalletAdapterService _mwa;
  final FlutterSecureStorage _storage;

  // ---------------------------------------------------------------------------
  // Storage keys
  // ---------------------------------------------------------------------------

  static const _kWalletKind = 'wallet_kind';

  // MWA
  static const _kMWAPubkey = 'mwa_pubkey_b58';
  static const _kMwaAuthToken = 'mwa_auth_token';

  // Seed Vault
  static const _kSeedVaultPubkey = 'seed_vault_pubkey_b58';
  static const _kSeedVaultAuthToken = 'seed_vault_auth_token';
  static const _kSeedVaultAccountId = 'seed_vault_account_id';
  static const _kSeedVaultDerivationPath = 'seed_vault_derivation_path';

  // ---------------------------------------------------------------------------
  // In-memory state
  // ---------------------------------------------------------------------------

  WalletKind? _kind;
  String? _pubkey;

  String? _mwaAuthToken;

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

  bool get isConnecting => _isConnecting;
  bool get isDisconnecting => _isDisconnecting;
  bool get isBusy => _isConnecting || _isDisconnecting;
  bool get isConnected => _pubkey != null;

  Object? get lastError => _lastError;

  WalletConnectError? get uiError =>
      _lastError is WalletConnectError ? _lastError as WalletConnectError : null;

  String? get mwaAuthToken => _mwaAuthToken;
  String? get mwaAddressB58 => _kind == WalletKind.mwa ? _pubkey : null;

  int? get seedVaultAuthToken => _seedVaultAuthToken;
  int? get seedVaultAccountId => _seedVaultAccountId;
  Uri? get seedVaultDerivationPath => _seedVaultDerivationPath;

  WalletSession? get session {
    final currentKind = _kind;
    final currentPubkey = _pubkey;
    if (currentKind == null || currentPubkey == null) return null;

    switch (currentKind) {
      case WalletKind.mwa:
        final token = _mwaAuthToken;
        if (token == null || token.isEmpty) return null;
        return MwaWalletSession(pubkey: currentPubkey, authToken: token);

      case WalletKind.seedVault:
        final token = _seedVaultAuthToken;
        final accountId = _seedVaultAccountId;
        final path = _seedVaultDerivationPath;

        if (token == null || accountId == null || path == null) return null;

        return SeedVaultWalletSession(
          pubkey: currentPubkey,
          authToken: token,
          accountId: accountId,
          derivationPath: path,
        );
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
        'Install a Solana wallet that supports Mobile Wallet Adapter (MWA), such as Phantom or Backpack, and try again.',
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
  // Auto restore
  // ---------------------------------------------------------------------------

  /// Best-effort restore on app launch.
  ///
  /// MWA:
  /// - restores UI state
  /// - restores local session into the MWA service if a token exists
  ///
  /// Seed Vault:
  /// - attempts to restore the previously persisted Seed Vault token/account
  /// - failures are expected on some boots and should not hard-fail the app
  Future<void> tryAutoConnect() async {
    if (_isConnecting) return;

    final savedKindStr = await _storage.read(key: _kWalletKind);
    final savedKind = WalletKindStorage.fromStorage(savedKindStr);
    if (savedKind == null) return;

    final savedPubkey = switch (savedKind) {
      WalletKind.mwa => await _storage.read(key: _kMWAPubkey),
      WalletKind.seedVault => await _storage.read(key: _kSeedVaultPubkey),
    };

    // Optimistic UI restore so the app can render quickly.
    if (savedPubkey != null && savedPubkey.isNotEmpty) {
      _pubkey = savedPubkey;
      _kind = savedKind;
      notifyListeners();
    }

    _isConnecting = true;
    _lastError = null;
    notifyListeners();

    try {
      switch (savedKind) {
        case WalletKind.mwa:
          final savedToken = await _storage.read(key: _kMwaAuthToken);
          final savedPubkey = await _storage.read(key: _kMWAPubkey);

          if (savedPubkey == null || savedPubkey.isEmpty) {
            await _clearPersisted();
            _resetInMemory();
            return;
          }

          _kind = WalletKind.mwa;
          _pubkey = savedPubkey;
          _mwaAuthToken = savedToken;

          if (savedToken != null && savedToken.isNotEmpty) {
            final pkBytes = Uint8List.fromList(base58decode(savedPubkey));
            if (pkBytes.length == 32) {
              _mwa.restoreLocalSession(
                authToken: savedToken,
                activeAddressB58: savedPubkey,
                activePubkeyBytes: pkBytes,
              );
            }
          }

          notifyListeners();
          return;

        case WalletKind.seedVault:
          final restored = await _tryRestoreSeedVault();
          if (!restored) {
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
        // Expected sometimes for Seed Vault on boot / process restore.
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
      _lastError = e is WalletConnectError ? e : _mapConnectError(e);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // User-initiated Seed Vault connect
  // ---------------------------------------------------------------------------

  /// Connects through Solana Seed Vault.
  ///
  /// Connection strategy:
  /// 1. Try restoring the previously persisted Seed Vault token/account
  /// 2. Try matching any already-authorized seed session
  /// 3. Fall back to interactive authorize flow
  ///
  /// This lets us prefer stable reconnects before prompting the user again.
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

      final hasPermission = await seedVault.checkPermission();
      if (!hasPermission) {
        warn('checkPermission() == false (continuing anyway)');
      }

      final savedPubkey = await _storage.read(key: _kSeedVaultPubkey);
      final savedIdStr = await _storage.read(key: _kSeedVaultAccountId);
      final savedId = int.tryParse(savedIdStr ?? '');
      final savedDpStr = await _storage.read(key: _kSeedVaultDerivationPath);

      log('saved pin: savedId=$savedId savedPubkey=$savedPubkey savedDp=$savedDpStr');

      // 1) Silent restore first.
      final restored = await _tryRestoreSeedVault();
      if (restored) {
        log('silent restore OK: acct=$_seedVaultAccountId pubkey=$_pubkey dp=$_seedVaultDerivationPath');

        await _storage.write(key: _kWalletKind, value: WalletKind.seedVault.storageValue);
        await _storage.write(key: _kSeedVaultPubkey, value: _pubkey);

        _mwaAuthToken = null;
        await _storage.delete(key: _kMwaAuthToken);

        notifyListeners();
        return;
      }

      log('silent restore failed. Will try other authorized seed sessions…');

      // 2) Try matching an existing authorized Seed Vault session.
      final match = await _findMatchingAuthorizedSeedSession();
      if (match != null) {
        final token = match.$1;
        final account = match.$2;

        log(
          'matched authorized seed session: token=$token acctId=${account.id} pk=${account.publicKeyEncoded} dp=${account.derivationPath}',
        );

        await _commitSeedVaultSession(token, account);

        _mwaAuthToken = null;
        await _storage.delete(key: _kMwaAuthToken);

        log(
          'committed matched session: acct=$_seedVaultAccountId pubkey=$_pubkey dp=$_seedVaultDerivationPath',
        );
        return;
      }

      log('no matching authorized seed session found. Falling back to interactive authorize…');

      // 3) Interactive authorize.
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

      Account? chosen;

      bool looksLikeDefaultSolanaPath(Uri dp) {
        final s = dp.toString();
        return s.contains("44'/501'/0'") ||
            s.contains("m/44'/501'/0'") ||
            s.contains("/44'/501'/0'") ||
            s.contains("44%27/501%27/0%27");
      }

      // Selection order:
      // 1) saved accountId
      // 2) saved pubkey
      // 3) isUserWallet
      // 4) default Solana path
      // 5) first
      if (savedId != null) {
        chosen = firstWhereOrNull(accounts, (a) => a.id == savedId);
        if (chosen != null) log('choose: matched savedId=$savedId');
      }

      if (chosen == null && savedPubkey != null && savedPubkey.isNotEmpty) {
        chosen = firstWhereOrNull(accounts, (a) => a.publicKeyEncoded == savedPubkey);
        if (chosen != null) log('choose: matched savedPubkey=$savedPubkey');
      }

      chosen ??= firstWhereOrNull(accounts, (a) => a.isUserWallet == true);
      if (chosen != null && chosen.isUserWallet == true) {
        log('choose: matched isUserWallet acctId=${chosen.id}');
      }

      if (chosen == null) {
        chosen = firstWhereOrNull(accounts, (a) => looksLikeDefaultSolanaPath(a.derivationPath));
        if (chosen != null) {
          log('choose: matched default Solana derivation path dp=${chosen.derivationPath}');
        }
      }

      chosen ??= accounts.first;

      log(
        'choose: final acctId=${chosen.id} pk=${chosen.publicKeyEncoded} dp=${chosen.derivationPath} user=${chosen.isUserWallet}',
      );

      await _commitSeedVaultSession(newToken, chosen);

      _mwaAuthToken = null;
      await _storage.delete(key: _kMwaAuthToken);

      log('connected+persisted: pubkey=$_pubkey acct=$_seedVaultAccountId dp=$_seedVaultDerivationPath');
    } catch (e) {
      _lastError = e is WalletConnectError
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
  // Restore helpers
  // ---------------------------------------------------------------------------

  /// Attempts to restore a persisted Seed Vault token/account selection.
  ///
  /// Returns true when a persisted token still resolves to a valid account set.
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

      final chosen = savedId != null
          ? accounts.firstWhere(
              (a) => a.id == savedId,
              orElse: () => accounts.firstWhere((a) => a.isUserWallet == true, orElse: () => accounts.first),
            )
          : accounts.firstWhere((a) => a.isUserWallet == true, orElse: () => accounts.first);

      _kind = WalletKind.seedVault;
      _pubkey = chosen.publicKeyEncoded;
      _mwaAuthToken = null;

      _seedVaultAuthToken = token;
      _seedVaultAccountId = chosen.id;
      _seedVaultDerivationPath = chosen.derivationPath;

      await _storage.write(key: _kSeedVaultPubkey, value: _pubkey);

      notifyListeners();
      return true;
    } catch (e) {
      icLogger.i('[WalletConnection] _tryRestoreSeedVault failed (expected sometimes): $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Signing-session bootstrap
  // ---------------------------------------------------------------------------

  /// Ensures a valid Seed Vault session exists before signing.
  ///
  /// Strategy:
  /// 1. try in-memory token
  /// 2. try persisted token
  /// 3. try already-authorized seed sessions
  /// 4. interactive authorize as a last resort
  Future<SeedVaultWalletSession> ensureSeedVaultSessionForSigning() async {
    final seedVault = SeedVault.instance;
    const purpose = Purpose.signSolanaTransaction;

    final available = await seedVault.isAvailable(allowSimulated: true);
    if (!available) {
      throw WalletConnectError('Seed Vault unavailable', 'Seed Vault is not available on this device.');
    }

    final inMemoryToken = _seedVaultAuthToken;
    if (inMemoryToken != null) {
      final accounts = await _tryAccountsForToken(inMemoryToken);
      if (accounts != null) {
        final chosen = _chooseAccountFromAccounts(accounts);
        return _commitSeedVaultSession(inMemoryToken, chosen);
      }
    }

    final persistedStr = await _storage.read(key: _kSeedVaultAuthToken);
    final persistedToken = _parseAuthToken(persistedStr);
    if (persistedToken != null) {
      final accounts = await _tryAccountsForToken(persistedToken);
      if (accounts != null) {
        final chosen = _chooseAccountFromAccounts(accounts);
        return _commitSeedVaultSession(persistedToken, chosen);
      }
    }

    final match = await _findMatchingAuthorizedSeedSession();
    if (match != null) {
      final token = match.$1;
      final account = match.$2;
      return _commitSeedVaultSession(token, account);
    }

    try {
      final newToken = await seedVault.authorizeSeed(purpose);
      final accounts = await seedVault.getParsedAccounts(newToken);

      if (accounts.isEmpty) {
        throw WalletConnectError('Seed Vault has no accounts', 'No accounts were found in Seed Vault.');
      }

      final chosen = _chooseAccountFromAccounts(accounts);
      return _commitSeedVaultSession(newToken, chosen);
    } catch (e) {
      throw WalletConnectError(
        'Seed Vault locked',
        'Unlock Seed Vault to sign this transaction.',
        debug: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MWA signing-session bootstrap
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  /// Disconnects the current wallet lane.
  ///
  /// For Seed Vault, when revoke=true:
  /// - all currently authorized Seed Vault rows are deauthorized
  /// - the provider waits briefly for Seed Vault/provider state to settle
  /// - only then are local persisted values cleared
  ///
  /// That settle delay is intentional and prevents immediate reconnect failures.
  Future<void> disconnect({bool revoke = true}) async {
    icLogger.i('[WalletConnection] disconnect called kind=$_kind revoke=$revoke');

    if (_isConnecting || _isDisconnecting) return;

    final currentKind = _kind;

    _isDisconnecting = true;
    _lastError = null;

    try {
      if (currentKind == WalletKind.mwa) {
        _resetInMemory();
        notifyListeners();

        await _clearPersisted();
        await _mwa.deauthorize(interactive: revoke);
        await Future.delayed(const Duration(milliseconds: 800));
        return;
      }

      if (currentKind == WalletKind.seedVault) {
        icLogger.i('[SeedVault][disconnect] starting');

        if (revoke) {
          await _deauthorizeAllSeedVaultSessions();
          await _waitForSeedVaultSync();
        }

        _resetInMemory();
        notifyListeners();
        await _clearPersisted();
        return;
      }

      _resetInMemory();
      notifyListeners();
      await _clearPersisted();
    } catch (e) {
      icLogger.w('[WalletConnection] disconnect failed: $e');
      _lastError = e;
    } finally {
      _isDisconnecting = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel
  // ---------------------------------------------------------------------------

  void cancelConnectAttempt({String reason = 'cancelled'}) {
    if (!_isConnecting) return;

    icLogger.i('[WalletConnection] cancelConnectAttempt: $reason');

    // If needed later:
    // _mwa.cancelActiveSession();

    _isConnecting = false;
    _lastError = WalletConnectError('Cancelled', 'Connection cancelled.');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

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
    final derivationPath = chosen.derivationPath as Uri;
    final accountId = chosen.id as int?;
    final pubkey = chosen.publicKeyEncoded as String?;

    _kind = WalletKind.seedVault;
    _pubkey = pubkey;
    _seedVaultAuthToken = token;
    _seedVaultAccountId = accountId;
    _seedVaultDerivationPath = derivationPath;

    await _storage.write(key: _kWalletKind, value: _kind!.storageValue);
    await _storage.write(key: _kSeedVaultPubkey, value: _pubkey);
    await _storage.write(key: _kSeedVaultAuthToken, value: token.toString());

    if (accountId == null || accountId <= 0) {
      await _storage.delete(key: _kSeedVaultAccountId);
    } else {
      await _storage.write(key: _kSeedVaultAccountId, value: accountId.toString());
    }

    await _storage.write(key: _kSeedVaultDerivationPath, value: derivationPath.toString());

    notifyListeners();

    return SeedVaultWalletSession(
      pubkey: _pubkey!,
      authToken: token,
      accountId: _seedVaultAccountId!,
      derivationPath: derivationPath,
    );
  }

  /// Reads currently authorized Seed Vault row IDs.
  ///
  /// In this provider setup, the row `_id` is what we pass back into
  /// `deauthorizeSeed(...)`.
  Future<List<int>> _getAuthorizedSeedTokens() async {
    try {
      final rows = await SeedVault.instance.getAuthorizedSeeds();

      final out = <int>[];
      for (final row in rows) {
        final dynamic value = row['_id'];

        if (value is int) {
          out.add(value);
        } else if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) out.add(parsed);
        } else if (value != null) {
          final match = RegExp(r'(\d+)').firstMatch(value.toString());
          final parsed = match == null ? null : int.tryParse(match.group(1)!);
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
    final inMemoryPubkey = _kind == WalletKind.seedVault ? _pubkey : null;
    final savedPubkey = inMemoryPubkey ?? await _storage.read(key: _kSeedVaultPubkey);

    final savedIdStr = await _storage.read(key: _kSeedVaultAccountId);
    final parsedId = int.tryParse(savedIdStr ?? '');
    final savedId = parsedId != null && parsedId > 0 ? parsedId : null;

    final tokens = await _getAuthorizedSeedTokens();
    if (tokens.isEmpty) return null;

    for (final token in tokens) {
      final accounts = await _tryAccountsForToken(token);
      if (accounts == null || accounts.isEmpty) continue;

      if (savedId != null) {
        for (final a in accounts) {
          final int? id = a.id as int?;
          if (id != null && id == savedId) return (token, a);
        }
      }

      if (savedPubkey != null && savedPubkey.isNotEmpty) {
        for (final a in accounts) {
          final String? pk = a.publicKeyEncoded as String?;
          if (pk != null && pk == savedPubkey) return (token, a);
        }
      }
    }

    return null;
  }

  Future<void> _deauthorizeAllSeedVaultSessions() async {
    final tokens = await _getAuthorizedSeedTokens();
    icLogger.i('[SeedVault][disconnect] revoking ${tokens.length} authorized session(s)');

    for (final token in tokens) {
      try {
        await SeedVault.instance.deauthorizeSeed(token);
      } catch (e) {
        icLogger.w('[SeedVault][disconnect] failed to revoke token=$token error=$e');
      }
    }
  }

  Future<void> _waitForSeedVaultSync() async {
    // Seed Vault/provider updates asynchronously after deauthorization.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _clearSeedVaultSigningOnlyMemory() {
    _seedVaultAuthToken = null;
    _seedVaultDerivationPath = null;
    // Intentionally keep pubkey/kind/accountId if optimistic restore already ran.
  }

  Future<void> _clearPersisted() async {
    await _storage.delete(key: _kWalletKind);

    await _storage.delete(key: _kMWAPubkey);
    await _storage.delete(key: _kMwaAuthToken);

    await _storage.delete(key: _kSeedVaultPubkey);
    await _storage.delete(key: _kSeedVaultAuthToken);
    await _storage.delete(key: _kSeedVaultAccountId);
    await _storage.delete(key: _kSeedVaultDerivationPath);
  }

  void _resetInMemory() {
    _kind = null;
    _pubkey = null;

    _mwaAuthToken = null;

    _seedVaultAuthToken = null;
    _seedVaultAccountId = null;
    _seedVaultDerivationPath = null;
  }

  int? _parseAuthToken(String? value) {
    if (value == null) return null;

    final direct = int.tryParse(value);
    if (direct != null) return direct;

    final match = RegExp(r'(\d+)').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  T? firstWhereOrNull<T>(List<T> list, bool Function(T item) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }
}
