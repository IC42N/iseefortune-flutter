import 'dart:typed_data';

import 'package:solana_seed_vault/solana_seed_vault.dart';
import 'package:iseefortune_flutter/solana/signing/versioned_tx_signer.dart';

class SeedVaultSigner implements VersionedTxSigner {
  SeedVaultSigner({required SeedVault seedVault, required AuthToken authToken, required Uri derivationPath})
    : _seedVault = seedVault,
      _authToken = authToken,
      _derivationPath = derivationPath;

  final SeedVault _seedVault;
  final AuthToken _authToken;
  final Uri _derivationPath;

  @override
  Future<Uint8List> signMessageBytes(Uint8List messageBytes) async {
    final res = await _seedVault.signMessages(
      authToken: _authToken,
      signingRequests: [
        SigningRequest(payload: messageBytes, requestedSignatures: [_derivationPath]),
      ],
    );

    if (res.isEmpty || res.first.signatures.isEmpty) {
      throw StateError('SeedVault returned no signatures');
    }

    final sig = res.first.signatures.first;
    if (sig.length != 64) {
      throw StateError('SeedVault signature len=${sig.length}, expected 64');
    }

    return sig;
  }
}
