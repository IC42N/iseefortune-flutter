import 'dart:convert';
import 'dart:typed_data';

import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

import 'package:iseefortune_flutter/solana/signing/versioned_tx_signer.dart';

/// Result returned after a successful send + confirmation.
class VersionedTxSendResult {
  final String signature;

  VersionedTxSendResult(this.signature);
}

/// Handles the full lifecycle of a **Versioned Solana transaction**
/// when using wallets that return **detached signatures**.
///
/// This class is currently used by:
/// - Seed Vault signing flows
///
/// The process is:
///
/// 1. Receive a **VersionedMessage** (base64 encoded) from the backend.
/// 2. Ask the wallet to sign the message bytes.
/// 3. Construct a full VersionedTransaction locally.
/// 4. Send the transaction via RPC.
/// 5. Wait for confirmation.
///
/// NOTE:
/// Mobile Wallet Adapter (MWA) does **not** use this path.
/// MWA signs and sends transactions directly in the wallet.
class VersionedTxSender {
  VersionedTxSender({required RpcClient rpc, required VersionedTxSigner signer})
    : _rpc = rpc,
      _signer = signer;

  /// RPC client used to submit transactions and check confirmation.
  final RpcClient _rpc;

  /// Wallet-specific signer implementation (Seed Vault).
  final VersionedTxSigner _signer;

  /// Signs a VersionedMessage, builds a transaction, sends it,
  /// and waits for confirmation.
  ///
  /// Parameters:
  /// - [messageB64]: Base64 encoded VersionedMessage bytes returned by backend
  /// - [commitment]: Confirmation level to wait for
  /// - [skipPreflight]: Skip RPC simulation
  /// - [maxRetries]: RPC retry count
  Future<VersionedTxSendResult> signSendAndConfirm({
    required String messageB64,
    Commitment commitment = Commitment.confirmed,
    bool skipPreflight = false,
    int maxRetries = 2,
  }) async {
    /// Decode the VersionedMessage returned by the Lambda/API.
    final messageBytes = Uint8List.fromList(base64Decode(messageB64));

    /// Ask wallet to sign the raw VersionedMessage bytes.
    ///
    /// Seed Vault returns a detached 64-byte Ed25519 signature.
    final sig = await _signer.signMessageBytes(messageBytes);

    /// Construct the full VersionedTransaction bytes.
    ///
    /// Solana VersionedTransaction format:
    ///
    /// shortvec(signature_count)
    /// signatures[]
    /// message_bytes
    ///
    final txBytes = _buildVersionedTxBytes(messageBytes: messageBytes, signatures: [sig]);

    /// Encode transaction for RPC submission.
    final txB64 = base64Encode(txBytes);

    /// Send transaction to Solana RPC.
    final signature = await _rpc.sendTransaction(
      txB64,
      encoding: Encoding.base64,
      skipPreflight: skipPreflight,
      maxRetries: maxRetries,
      preflightCommitment: commitment,
    );

    ///  Wait for transaction confirmation.
    await confirmSignature(rpc: _rpc, signature: signature, commitment: commitment);

    return VersionedTxSendResult(signature);
  }

  /// Polls the RPC until the transaction reaches the desired commitment.
  ///
  /// Throws:
  /// - if transaction fails
  /// - if confirmation timeout occurs
  static Future<void> confirmSignature({
    required RpcClient rpc,
    required String signature,
    Commitment commitment = Commitment.confirmed,
  }) async {
    const maxWaitMs = 20 * 1000;
    const stepMs = 700;

    final started = DateTime.now().millisecondsSinceEpoch;

    while (true) {
      final st = await rpc.getSignatureStatuses([signature], searchTransactionHistory: true);

      final info = st.value.isNotEmpty ? st.value.first : null;

      if (info != null) {
        /// Transaction executed but failed.
        if (info.err != null) {
          throw StateError('transaction failed: ${jsonEncode(info.err)}');
        }

        /// confirmationStatus may be:
        /// - processed
        /// - confirmed
        /// - finalized
        final cs = info.confirmationStatus.toString();

        final ok = commitment == Commitment.finalized
            ? cs.contains('finalized')
            : (cs.contains('confirmed') || cs.contains('finalized'));

        if (ok) return;
      }

      /// Abort if confirmation takes too long.
      if (DateTime.now().millisecondsSinceEpoch - started > maxWaitMs) {
        throw StateError('confirm timeout for $signature');
      }

      await Future<void>.delayed(const Duration(milliseconds: stepMs));
    }
  }

  /// Builds the raw VersionedTransaction byte layout.
  ///
  /// Layout:
  ///
  /// shortvec(len(signatures))
  /// signature[0]
  /// signature[1]
  /// ...
  /// message_bytes
  Uint8List _buildVersionedTxBytes({required Uint8List messageBytes, required List<Uint8List> signatures}) {
    final out = BytesBuilder();

    /// Encode number of signatures
    out.add(_encodeShortVecLen(signatures.length));

    /// Append each signature
    for (final s in signatures) {
      if (s.length != 64) {
        throw StateError('signature must be 64 bytes');
      }
      out.add(s);
    }

    /// Append VersionedMessage bytes
    out.add(messageBytes);

    return out.toBytes();
  }

  /// Encodes a Solana "shortvec" length.
  ///
  /// Solana uses a variable-length integer encoding where
  /// the high bit indicates continuation.
  Uint8List _encodeShortVecLen(int n) {
    final bytes = <int>[];

    var rem = n;

    while (true) {
      var elem = rem & 0x7f;
      rem >>= 7;

      if (rem == 0) {
        bytes.add(elem);
        break;
      } else {
        elem |= 0x80;
        bytes.add(elem);
      }
    }

    return Uint8List.fromList(bytes);
  }
}
