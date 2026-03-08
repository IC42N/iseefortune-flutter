import 'dart:typed_data';
import 'package:solana_borsh/borsh.dart';
import 'package:solana_borsh/models.dart';

import 'package:iseefortune_flutter/models/tier_model.dart';
import 'package:solana_borsh/types.dart';

class ConfigModel extends BorshObject {
  ConfigModel({
    required this.pauseBet,
    required this.pauseWithdraw,
    required this.authority,
    required this.feeVault,
    required this.baseFeeBps,
    required this.betCutoffSlots,
    required this.startedAt,
    required this.startedEpoch,
    required this.primaryRollOverNumber,
    required this.tiers,
    required this.bump,
    required this.minFeeBps,
    required this.rolloverFeeStepBps,
    required this.reserved,
  });

  final int pauseBet;
  final int pauseWithdraw;
  final String authority; // base58
  final String feeVault; // base58
  final int baseFeeBps;
  final BigInt betCutoffSlots;
  final int startedAt; // i64
  final BigInt startedEpoch; // u64
  final int primaryRollOverNumber;
  final List<TierSettings> tiers; // length 5
  final int bump;
  final int minFeeBps;
  final int rolloverFeeStepBps;
  final Uint8List reserved;

  static final _tierStruct = borsh.struct(TierSettings.staticSchema);

  static BorshSchema get staticSchema => {
    'pauseBet': borsh.u8,
    'pauseWithdraw': borsh.u8,
    'authority': borsh.pubkey,
    'feeVault': borsh.pubkey,
    'baseFeeBps': borsh.u16,
    'betCutoffSlots': borsh.u64,
    'startedAt': borsh.i64,
    'startedEpoch': borsh.u64,
    'primaryRollOverNumber': borsh.u8,
    'tiers': borsh.array(_tierStruct, 5),
    'bump': borsh.u8,
    'minFeeBps': borsh.u16,
    'rolloverFeeStepBps': borsh.u16,
    'reserved': borsh.array(borsh.u8, 16),
  };

  @override
  BorshSchema get borshSchema => staticSchema;

  factory ConfigModel.fromJson(Map<String, dynamic> json) => ConfigModel(
    pauseBet: json['pauseBet'] as int,
    pauseWithdraw: json['pauseWithdraw'] as int,
    authority: json['authority'] as String,
    feeVault: json['feeVault'] as String,
    baseFeeBps: json['baseFeeBps'] as int,
    betCutoffSlots: json['betCutoffSlots'] as BigInt,
    startedAt: json['startedAt'] as int,
    startedEpoch: json['startedEpoch'] as BigInt,
    primaryRollOverNumber: json['primaryRollOverNumber'] as int,

    // TierSettings comes back as List<dynamic> of Map<String, dynamic>
    tiers: (json['tiers'] as List)
        .map((e) => TierSettings.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false),

    bump: json['bump'] as int,
    minFeeBps: json['minFeeBps'] as int,
    rolloverFeeStepBps: json['rolloverFeeStepBps'] as int,

    reserved: json['reserved'] is Uint8List
        ? (json['reserved'] as Uint8List)
        : Uint8List.fromList(List<int>.from(json['reserved'] as List)),
  );

  @override
  Map<String, dynamic> toJson() => {
    'pauseBet': pauseBet,
    'pauseWithdraw': pauseWithdraw,
    'authority': authority,
    'feeVault': feeVault,
    'baseFeeBps': baseFeeBps,
    'betCutoffSlots': betCutoffSlots,
    'startedAt': startedAt,
    'startedEpoch': startedEpoch,
    'primaryRollOverNumber': primaryRollOverNumber,
    'tiers': tiers.map((t) => t.toJson()).toList(growable: false),
    'bump': bump,
    'minFeeBps': minFeeBps,
    'rolloverFeeStepBps': rolloverFeeStepBps,
    'reserved': reserved.toList(),
  };

  bool get isBettingPaused => pauseBet != 0;
  bool get isWithdrawPaused => pauseWithdraw != 0;

  TierSettings? tier(int tierId) {
    for (final t in tiers) {
      if (t.tierId == tierId) return t;
    }
    return null;
  }
}
