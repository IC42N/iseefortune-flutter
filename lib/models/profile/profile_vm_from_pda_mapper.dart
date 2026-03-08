// lib/ui/profile/profile_vm_mapper.dart
import 'package:iseefortune_flutter/models/profile/profile_pda_model.dart';
import 'package:iseefortune_flutter/models/profile/profile_view_model.dart';
import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';
import 'package:iseefortune_flutter/utils/solana/pubkey.dart';

ProfileViewModel buildProfileVMFromPDA({required String walletPubkey, required PlayerProfilePDAModel pda}) {
  final handle = getHandleFromPubkey(walletPubkey);
  final tickets = pda.ticketsAvailable;
  final xp = pda.xpPoints;
  final totalBets = pda.totalBets;
  final isNew = (totalBets == BigInt.zero && xp == 0);
  final hueDeg = isNew ? 45 : 210; // opinion: gold-ish for new
  final pal = RowHuePalette(hueDeg.toDouble());
  return ProfileViewModel(
    handle: handle,
    xp: xp,
    tickets: tickets,
    hueDeg: hueDeg, // opinion: gold-ish for new
    pal: pal,
  );
}

ProfileViewModel buildOtherProfileVMFromPDA({required String handle, required PlayerProfilePDAModel pda}) {
  final tickets = pda.ticketsAvailable;
  final xp = pda.xpPoints;
  final totalBets = pda.totalBets;
  final isNew = (totalBets == BigInt.zero && xp == 0);
  final hueDeg = isNew ? 45 : 210; // opinion: gold-ish for new
  final pal = RowHuePalette(hueDeg.toDouble());
  return ProfileViewModel(
    handle: handle,
    xp: xp,
    tickets: tickets,
    hueDeg: hueDeg, // opinion: gold-ish for new
    pal: pal,
  );
}
