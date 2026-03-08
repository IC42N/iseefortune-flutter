import 'package:iseefortune_flutter/api/api_client.dart';
import 'package:iseefortune_flutter/models/profile/profile_stats_model.dart';

class ProfileStatsService {
  ProfileStatsService({ApiClient? api}) : _api = api ?? ApiClient(baseUrl: 'https://api.iseefortune.com');

  final ApiClient _api;

  /// GET /player-stats?handle={HANDLE}
  Future<ProfileStatsModel> fetchProfileStats({required String handle}) async {
    final h = handle.trim();
    if (h.isEmpty) throw ArgumentError('handle is empty');

    return _api.getJson<ProfileStatsModel>(
      '/player-stats',
      query: {'handle': h},
      headers: const {'accept': 'application/json'},
      parser: (json) {
        if (json is! Map<String, dynamic>) {
          throw StateError('ProfileStatsService: expected JSON object');
        }
        return ProfileStatsModel.fromApiEnvelope(json);
      },
    );
  }
}
