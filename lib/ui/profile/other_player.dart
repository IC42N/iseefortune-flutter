// import 'package:flutter/material.dart';
// import 'package:iseefortune_flutter/models/profile/profile_vm_from_pda_mapper.dart';
// import 'package:iseefortune_flutter/providers/profile/profile_pda_provider.dart';
// import 'package:iseefortune_flutter/providers/profile/profile_stats_provider.dart';
// import 'package:iseefortune_flutter/ui/profile/profile_modal.dart';
// import 'package:iseefortune_flutter/ui/profile/widgets/overhang_header.dart';
// //import 'package:iseefortune_flutter/ui/shared/cosmic_modal.dart';
// import 'package:iseefortune_flutter/ui/shared/cosmic_modal_shell.dart';
// import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
// import 'package:iseefortune_flutter/utils/profile/rank.dart';
// import 'package:provider/provider.dart';

// /// TODO: We are going to need a new lambda function API Gateway endpoint to first take in a handle.
// /// Once it takes in the handle, it should query the dynamodb table to get the wallet address.
// /// Once mapped to wallet address, we can query the profile PDA and return the profile details with the player stats
// /// One query. Return full profile data without full wallet addresss leak.

// Future<void> openOtherPlayerProfile(BuildContext context, String handle) async {
//   const hueDeg = 210;

//   // NOTE: We wrap the entire sheet so we only build the VM once per rebuild.
//   await showModalBottomSheet(
//     context: context,
//     useRootNavigator: true,
//     isScrollControlled: true,
//     enableDrag: true,
//     backgroundColor: Colors.transparent,
//     barrierColor: Colors.black.withOpacityCompat(0.55),
//     builder: (_) {
//       return Consumer<ProfilePdaProvider>(
//         builder: (context, pdaProv, _) {
//           final pda = pdaProv.profile;

//           if (pda == null) {
//             return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
//           }

//           final vm = buildOtherProfileVMFromPDA(handle: handle, pda: pda);

//           final stats = context.watch<ProfileStatsProvider>().getCached(vm.handle);
//           final loading = context.select<ProfileStatsProvider, bool>((p) => p.isLoading(vm.handle));

//           final totalCorrect = stats?.totalWins ?? 0;
//           final totalWrong = stats?.totalLosses ?? 0;
//           final totalGames = totalCorrect + totalWrong;
//           final bestWinStreak = stats?.bestWinStreak ?? 0;

//           final rankLabel = getPlayerRankFromStats(
//             totalCorrect: totalCorrect,
//             totalWrong: totalWrong,
//             totalGames: totalGames,
//             bestWinStreak: bestWinStreak,
//           );
//           final subtitle = loading ? 'Updating…' : rankLabel;

//           // Kick a refresh once the handle exists.
//           // microtask avoids doing provider work directly during build.
//           final handle = vm.handle.trim();
//           if (handle.isNotEmpty && handle != '—') {
//             Future.microtask(() {
//               if (!context.mounted) return;
//               context.read<ProfileStatsProvider>().refresh(handle);
//             });
//           }

//           return CosmicModalShell(
//             title: 'PROFILE',
//             hueDeg: hueDeg,
//             overhangLift: 76,
//             overhang: ProfileOverhangHeader(
//               handle: vm.handle,
//               subtitle: subtitle,
//               accent: vm.pal.pkColor,
//               onClose: () => Navigator.of(context).pop(),
//             ),
//             showClouds: true,
//             showStars: true,
//             showHands: true,
//             child: ProfileModal(vm: vm, isSelf: true, handle: vm.handle),
//           );
//         },
//       );
//     },
//   );
// }

// // /// Snapshot: fetch fresh data once per open.
// // /// Use this when tapping other players in history / leaderboards.
// // Future<void> openOtherPlayerProfileSnapshot({
// //   required BuildContext context,
// //   required String walletPubkey,
// //   int? hueDeg,
// // }) async {
// //   final prov = context.read<ProfilePdaProvider>();

// //   // --- YOU MUST IMPLEMENT ONE OF THESE IN ProfilePdaProvider ---
// //   // Option A (preferred): a method that returns a PDA without mutating "my profile"
// //   // final pda = await prov.fetchProfileOnce(walletPubkey);

// //   // Option B (minimal if you don’t have fetch yet): if provider has some existing API,
// //   // call it here, then read from a temporary map cache.
// //   final pda = await prov.fetchProfileOnce(walletPubkey);

// //   final vm = buildProfileVM(walletPubkey: walletPubkey, pda: pda);
// //   final pal = RowHuePalette(vm.hueDeg.toDouble());

// //   if (!mounted) return;

// //   await CosmicModal.show(
// //     context,
// //     title: 'PROFILE',
// //     hueDeg: hueDeg ?? vm.hueDeg,
// //     isScrollControlled: true,
// //     overhangLift: 36,
// //     overhang: ProfileOverhangHeader(
// //       handle: vm.handle,
// //       subtitle: vm.rankLabel ?? '—',
// //       accent: pal.pkColor,
// //       onClose: () => Navigator.of(context).pop(),
// //     ),
// //     child: ProfileModal(vm: vm, isSelf: false),
// //   );
// // }
