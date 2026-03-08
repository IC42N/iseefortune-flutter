import 'package:solana/solana.dart';

/// Identifies the ended game we want to resolve in the modal.
///
/// We intentionally keep this tiny and immutable.
/// - epoch + tier: canonical identity in your protocol
/// - resolvedGamePda: derived once for fast subscription
class ResolutionAnchor {
  const ResolutionAnchor({required this.epoch, required this.tier, required this.resolvedGamePda});

  final int epoch;
  final int tier;
  final Ed25519HDPublicKey resolvedGamePda;

  @override
  bool operator ==(Object other) =>
      other is ResolutionAnchor &&
      other.epoch == epoch &&
      other.tier == tier &&
      other.resolvedGamePda == resolvedGamePda;

  @override
  int get hashCode => Object.hash(epoch, tier, resolvedGamePda);
}
