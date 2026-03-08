import 'dart:convert';
import 'dart:typed_data';

import 'package:iseefortune_flutter/solana/service/client.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

/// ---------------------------------------------------------------------------
/// Fee estimation helpers
/// ---------------------------------------------------------------------------
/// Solana fees depend on the *exact message* being sent (accounts, instructions,
/// signatures, etc). The most accurate way to estimate is:
///   1) compile the Message using a recent blockhash + fee payer
///   2) base64-encode the compiled message bytes
///   3) call `getFeeForMessage`
///
/// Notes:
/// - This estimates the base transaction fee.
/// - If you later add ComputeBudget instructions or priority fees, those are
///   separate from this estimate (priority fee is paid via compute unit price).
/// ---------------------------------------------------------------------------

/// Returns an approximate "baseline" network fee in lamports.
///
/// Implementation detail:
/// - Builds a dummy 0-lamport SystemProgram transfer message using a valid
///   pubkey as both payer + recipient.
/// - Compiles it with a real recent blockhash.
/// - Asks the cluster what fee it would charge for that message.
///
/// This is useful as a fallback/quick default, but for *real transactions*
/// use [estimateFeeForInstructions] with your actual instructions.
Future<int> getNetworkFee({int fallbackLamports = 5000}) async {
  final rpc = SolanaClientService().rpcClient;

  try {
    // Any valid pubkey works (it doesn't need to have funds for fee estimation).
    final dummyPayer = Ed25519HDPublicKey.fromBase58('7f2YjYvV43sjzkQbqN4dR7xt9nsu1dUQ5G9zMWF42pR3');

    // Fetch a real blockhash from the cluster (required to compile a message).
    final latestBlockhash = await rpc.getLatestBlockhash();
    final blockhash = latestBlockhash.value.blockhash;

    // 0-lamport transfer just to create a "typical" simple message shape.
    final instruction = SystemInstruction.transfer(
      fundingAccount: dummyPayer,
      recipientAccount: dummyPayer,
      lamports: 0,
    );

    // Compile the message exactly as a wallet would.
    final compiled = Message.only(instruction).compile(recentBlockhash: blockhash, feePayer: dummyPayer);

    // RPC expects base64-encoded compiled message bytes.
    final msgBytes = Uint8List.fromList(compiled.toByteArray().toList());
    final msgBase64 = base64Encode(msgBytes);

    final fee = await rpc.getFeeForMessage(msgBase64);

    // If cluster can't compute it, return a sensible fallback.
    return fee ?? fallbackLamports;
  } catch (e, st) {
    icLogger.e("Failed to get baseline network fee", error: e, stackTrace: st);
    return fallbackLamports;
  }
}

/// Convenience wrapper for estimating the fee for a *single SOL transfer*.
///
/// Use this when you want to show users:
/// "Estimated fee: X lamports"
/// for a standard transfer.
Future<int> estimateFeeForTransfer({
  required Ed25519HDPublicKey from,
  required Ed25519HDPublicKey to,
  required int lamports,
  String? recentBlockhash,
  int fallbackLamports = 5000,
}) {
  final ix = SystemInstruction.transfer(fundingAccount: from, recipientAccount: to, lamports: lamports);

  return estimateFeeForInstructions(
    feePayer: from,
    instructions: [ix],
    recentBlockhash: recentBlockhash,
    fallbackLamports: fallbackLamports,
  );
}

/// Returns the fee (lamports) for the *exact* message you plan to send.
///
/// Pass the same:
/// - [instructions]
/// - [feePayer]
/// - [recentBlockhash] (optional; fetched if null)
///
/// This gives you the most accurate base fee estimate available via RPC.
Future<int> estimateFeeForInstructions({
  required Ed25519HDPublicKey feePayer,
  required List<Instruction> instructions,
  String? recentBlockhash,
  int fallbackLamports = 5000,
}) async {
  final rpc = SolanaClientService().rpcClient;

  try {
    // If caller didn't provide one, fetch a recent blockhash.
    final blockhash = recentBlockhash ?? (await rpc.getLatestBlockhash()).value.blockhash;

    // Compile the message exactly like it will be signed.
    final compiled = Message(
      instructions: instructions,
    ).compile(recentBlockhash: blockhash, feePayer: feePayer);

    // Base64 encode the compiled message bytes for `getFeeForMessage`.
    final msgBytes = Uint8List.fromList(compiled.toByteArray().toList());
    final msgBase64 = base64Encode(msgBytes);

    // If RPC returns null, return fallback (NOT 0).
    return await rpc.getFeeForMessage(msgBase64) ?? fallbackLamports;
  } catch (e, st) {
    icLogger.e("Failed to estimate fee for instructions", error: e, stackTrace: st);
    return fallbackLamports;
  }
}

int calculateFeeBps(BigInt netPrizePoolLamports, BigInt protocolFeeLamports) {
  final gross = netPrizePoolLamports + protocolFeeLamports;
  if (gross == BigInt.zero) return 0;

  final bps = (protocolFeeLamports * BigInt.from(10000)) ~/ gross;
  return bps.toInt();
}

String feeBpsToPercent(int feeBps) {
  final percent = feeBps / 100;
  return '${percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 2)}%';
}
