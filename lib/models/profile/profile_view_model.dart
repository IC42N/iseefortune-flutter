import 'package:iseefortune_flutter/utils/numbers/number_colors.dart';

class ProfileViewModel {
  ProfileViewModel({
    required this.handle,
    required this.hueDeg,
    required this.xp,
    required this.tickets,
    required this.pal,
  });
  final String handle;
  final int hueDeg;
  final int xp;
  final int tickets;
  final RowHuePalette pal;
  static int hueFromNumber(int n) => hueForNumber(n).round();
}
