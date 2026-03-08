import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solana/solana.dart';

class AppConstants {
  // App version
  static const String appVersion = '1.0.0';

  static const int lamportsPerSol = 1000000000;
  // API base URL
  static const String apiBaseUrl = 'https://api.iseefortune.com/';

  static const String apiKey = 'Aot6nqsLmryKjAL1UnRt';

  // Raw API endpoint string
  static const String rawAPIURL = 'https://bernette-tb3sav-fast-mainnet.helius-rpc.com';

  static final rpcClient = RpcClient("https://bernette-tb3sav-fast-mainnet.helius-rpc.com");

  static const String wsRawAPIURL =
      'wss://mainnet.helius-rpc.com/?api-key=e9be3c89-9113-4c5d-be19-4dfc99d8c8f4';

  static const List<String> httpRpcUrls = [
    'https://bernette-tb3sav-fast-mainnet.helius-rpc.com',
    'https://api.mainnet-beta.solana.com',
  ];

  static const List<String> wsRpcUrls = [
    'wss://bernette-tb3sav-fast-mainnet.helius-rpc.com',
    'wss://api.mainnet-beta.solana.com',
  ];

  static final wsClientRawURL = 'wss://mainnet.helius-rpc.com/?api-key=e9be3c89-9113-4c5d-be19-4dfc99d8c8f4';

  static final TextStyle solFontStyle = GoogleFonts.archivoBlack(fontSize: 77, color: Colors.black);

  // //Skrambled Icon
  // static const IconData skramblIconOutlined = Icons.token_outlined;
  // static const IconData skramblIcon = Icons.token;
}

// class AppAssets {
//   AppAssets._();
//   static const solanaLogoBlack = 'assets/solana/Solana-Black.svg';
//   static const solanaLogoWhite = 'assets/solana/Solana-White.svg';
// }
