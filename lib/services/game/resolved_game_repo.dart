import 'package:iseefortune_flutter/models/game/game_unified_model.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_chain_service.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_db_service.dart';
import 'package:iseefortune_flutter/services/game/resolved_game_extras_service.dart';
import 'package:iseefortune_flutter/utils/logger.dart';

class ResolvedGameRepository {
  ResolvedGameRepository({
    required ResolvedGameApiService api,
    required ResolvedGameService chain,
    required ResolvedGameExtrasApiService extrasApi,
  }) : _api = api,
       _chain = chain,
       _extrasApi = extrasApi;

  final ResolvedGameApiService _api;
  final ResolvedGameService _chain;
  final ResolvedGameExtrasApiService _extrasApi;

  final Map<String, ResolvedGameHistoryModel> _cache = {};

  String _key(int epoch, int tier) => '$epoch:$tier';

  Future<ResolvedGameHistoryModel> getByEpoch({required int epoch, required int tier}) async {
    if (epoch < 0) throw Exception('Invalid epoch=$epoch');

    final key = _key(epoch, tier);
    final cached = _cache[key];
    if (cached != null) return cached;

    // 1) Try API first
    try {
      //icLogger.i("ResolvedGameRepository: trying API epoch=$epoch tier=$tier");
      final dto = await _api.getByEpoch(epoch: epoch, tier: tier, includeExtras: true);

      if (dto == null) {
        //icLogger.w("ResolvedGameRepository: API returned null epoch=$epoch tier=$tier (will fallback to chain)",);
      } else {
        //icLogger.i("ResolvedGameRepository: API hit epoch=$epoch tier=$tier");
        final model = ResolvedGameHistoryModel.fromApi(dto);
        _cache[key] = model;
        return model;
      }
    } catch (e, st) {
      icLogger.e("ResolvedGameRepository: API threw (will fallback to chain) epoch=$epoch tier=$tier err=$e");
      icLogger.e(st.toString());
    }

    //icLogger.w("ResolvedGameRepository: FETCHING FROM CHAIN epoch=$epoch tier=$tier");

    final chainModel = await _chain.fetchResolvedGame(epoch: epoch, tier: tier, commitment: 'finalized');
    var model = ResolvedGameHistoryModel.fromChain(chainModel);

    // If rollover, you already hide winners/tickets UI, so no need to fetch extras.
    if (!model.isRollover) {
      try {
        final extras = await _extrasApi.getExtras(epoch: epoch, tier: tier);
        if (extras != null) {
          model = ResolvedGameHistoryModel(
            gameEpoch: model.gameEpoch,
            epoch: model.epoch,
            tier: model.tier,
            winningNumber: model.winningNumber,
            netPotLamports: model.netPotLamports,
            grossPotLamports: model.grossPotLamports,
            feeLamports: model.feeLamports,
            feeBps: model.feeBps,
            winnersCount: model.winnersCount,
            losersCount: model.losersCount,
            totalPredictions: model.totalPredictions,
            secondaryRolloverNumber: model.secondaryRolloverNumber,
            arweaveResultsUri: model.arweaveResultsUri,
            resolveTxSignature: model.resolveTxSignature,
            updatedAt: model.updatedAt,
            source: model.source,
            blockhash: model.blockhash,
            endSlot: model.endSlot,
            winners: extras.winners,
            tickets: extras.tickets,
            isRollover: model.isRollover,
            rolloverReason: model.rolloverReason,
          );
        }
      } catch (e) {
        // non-fatal; keep chain-only view
      }
    }

    _cache[key] = model;
    return model;
  }
}
