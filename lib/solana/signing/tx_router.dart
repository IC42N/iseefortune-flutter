import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:iseefortune_flutter/providers/wallet_connection_provider.dart';
import 'package:iseefortune_flutter/solana/signing/seed_vault_signer.dart';
import 'package:iseefortune_flutter/solana/versioned_tx_sender.dart';
import 'package:iseefortune_flutter/solana/wallet/wallet_adapter_services.dart';
import 'package:iseefortune_flutter/utils/logger.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:solana_seed_vault/solana_seed_vault.dart';

class TxRouter {
  TxRouter({required this.walletConn, required this.rpc, required this.seedVault, required this.mwa});

  final WalletConnectionProvider walletConn;
  final RpcClient rpc;
  final SeedVault seedVault;
  final SolanaWalletAdapterService mwa;

  Future<String> signSendAndConfirm({
    required String messageB64,
    required String transactionB64,
    Commitment commitment = Commitment.confirmed,
    bool skipPreflight = false,
    int maxRetries = 2,
  }) async {
    final k = walletConn.kind;
    final startingPubkey = walletConn.pubkey;

    if (k == null) throw StateError('No wallet connected');
    if (startingPubkey == null || startingPubkey.isEmpty) {
      throw StateError('No wallet pubkey available');
    }

    switch (k) {
      case WalletKind.seedVault:
        {
          final s = await walletConn.ensureSeedVaultSessionForSigning();

          if (walletConn.pubkey != startingPubkey) {
            throw StateError('Wallet changed during signing flow');
          }

          final signer = SeedVaultSigner(
            seedVault: seedVault,
            authToken: s.authToken,
            derivationPath: s.derivationPath,
          );

          final sender = VersionedTxSender(rpc: rpc, signer: signer);

          final res = await sender.signSendAndConfirm(
            messageB64: messageB64,
            commitment: commitment,
            skipPreflight: skipPreflight,
            maxRetries: maxRetries,
          );

          return res.signature;
        }

      case WalletKind.mwa:
        {
          await walletConn.ensureMwaConnectedForSigning();

          if (walletConn.pubkey != startingPubkey) {
            throw StateError('Wallet changed during signing flow');
          }

          icLogger.i('[TxRouter][MWA] requesting wallet signature...');
          final signedTxBytes = await mwa.signTransactionB64(transactionB64: transactionB64);
          icLogger.i('[TxRouter][MWA] signed tx received len=${signedTxBytes.length}');

          // Wait for Flutter to be fully foregrounded again before hitting RPC.
          await _waitUntilAppResumed();
          await Future<void>.delayed(const Duration(milliseconds: 900));

          final signedTxB64 = base64Encode(signedTxBytes);

          icLogger.i('[TxRouter][MWA] sending signed tx via RPC...');
          final signature = await rpc.sendTransaction(
            signedTxB64,
            encoding: Encoding.base64,
            skipPreflight: skipPreflight,
            maxRetries: maxRetries,
            preflightCommitment: commitment,
          );
          icLogger.i('[TxRouter][MWA] sendTransaction success sig=$signature');

          await VersionedTxSender.confirmSignature(rpc: rpc, signature: signature, commitment: commitment);

          icLogger.i('[TxRouter][MWA] confirmed sig=$signature');
          return signature;
        }
    }
  }

  Future<void> _waitUntilAppResumed({Duration timeout = const Duration(seconds: 8)}) async {
    final binding = WidgetsBinding.instance;
    final currentState = binding.lifecycleState;

    icLogger.i('[TxRouter] lifecycle before RPC send: $currentState');

    if (currentState == AppLifecycleState.resumed) {
      return;
    }

    final completer = Completer<void>();

    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (!completer.isCompleted) {
          icLogger.i('[TxRouter] app resumed');
          completer.complete();
        }
      },
    );

    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      icLogger.w('[TxRouter] timed out waiting for resumed state; continuing anyway');
    } finally {
      listener.dispose();
    }
  }
}
