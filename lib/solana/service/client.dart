import 'package:iseefortune_flutter/constants/app.dart';
import 'package:solana/solana.dart';

class SolanaClientService {
  static final SolanaClientService _instance = SolanaClientService._internal();

  factory SolanaClientService() => _instance;

  late final RpcClient rpcClient;

  SolanaClientService._internal() {
    rpcClient = AppConstants.rpcClient;
  }
}
