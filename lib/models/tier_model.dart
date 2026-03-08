import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:solana_borsh/models.dart';
import 'package:solana_borsh/types.dart';

class TierSettings extends BorshObject {
  TierSettings({
    required this.tierId,
    required this.active,
    required this.minBetLamports,
    required this.maxBetLamports,
    required this.curveFactor,
    required this.ticketRewardBps,
    required this.ticketRewardMax,
    required this.ticketsPerRecipient,
    required this.reserved,
  });

  final int tierId; // u8
  final int active; // u8
  final BigInt minBetLamports; // u64
  final BigInt maxBetLamports; // u64
  final double curveFactor; // f32
  final int ticketRewardBps; // u16
  final int ticketRewardMax; // u16
  final int ticketsPerRecipient; // u8
  final Uint8List reserved; // [u8; 10]

  static BorshSchema get staticSchema => {
    'tierId': borsh.u8,
    'active': borsh.u8,
    'minBetLamports': borsh.u64,
    'maxBetLamports': borsh.u64,
    'curveFactor': borsh.f32,
    'ticketRewardBps': borsh.u16,
    'ticketRewardMax': borsh.u16,
    'ticketsPerRecipient': borsh.u8,
    'reserved': borsh.array(borsh.u8, 10), // [u8; 10]
  };

  @override
  BorshSchema get borshSchema => staticSchema;

  factory TierSettings.fromJson(Map<String, dynamic> json) => TierSettings(
    tierId: json['tierId'] as int,
    active: json['active'] as int,
    minBetLamports: json['minBetLamports'] as BigInt,
    maxBetLamports: json['maxBetLamports'] as BigInt,
    curveFactor: (json['curveFactor'] as num).toDouble(),
    ticketRewardBps: json['ticketRewardBps'] as int,
    ticketRewardMax: json['ticketRewardMax'] as int,
    ticketsPerRecipient: json['ticketsPerRecipient'] as int,
    reserved: Uint8List.fromList(List<int>.from(json['reserved'] as List)),
  );

  @override
  Map<String, dynamic> toJson() => {
    'tierId': tierId,
    'active': active,
    'minBetLamports': minBetLamports,
    'maxBetLamports': maxBetLamports,
    'curveFactor': curveFactor,
    'ticketRewardBps': ticketRewardBps,
    'ticketRewardMax': ticketRewardMax,
    'ticketsPerRecipient': ticketsPerRecipient,
    'reserved': reserved.toList(),
  };

  // ---- convenience helpers (optional, mirrors Rust) ----

  bool get isActive => active != 0;

  bool isValidBet(BigInt lamports) => lamports >= minBetLamports && lamports <= maxBetLamports;
}
