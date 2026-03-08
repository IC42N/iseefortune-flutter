import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

/// Lightweight service for fetching SOL price in USD.
/// - Uses CoinGecko public API
/// - In-memory cache to avoid rate limits
/// - Retries transient failures with exponential backoff
///
/// Designed for UI display only (never for financial logic).
class SolPriceService {
  SolPriceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ---------------------------------------------------------------------------
  // Simple in-memory cache (static = shared across instances)
  // ---------------------------------------------------------------------------
  static double? _cachedUsd;
  static DateTime? _cachedAt;

  /// Fetch SOL price in USD.
  ///
  /// Behavior:
  /// - Returns cached value if it is still within [cacheTtl]
  /// - Retries up to 3 times on transient HTTP errors (429 / 5xx)
  /// - Uses exponential backoff with jitter
  /// - Returns stale cached value on total failure (if available)
  /// - Returns null if no cached value exists
  ///
  /// This allows the UI to:
  /// - Show USD when available
  /// - Gracefully hide USD if unavailable
  Future<double?> fetch({Duration cacheTtl = const Duration(seconds: 45)}) async {
    // Serve from cache if it is still fresh
    if (_cachedUsd != null && _cachedAt != null && DateTime.now().difference(_cachedAt!) < cacheTtl) {
      return _cachedUsd;
    }

    // CoinGecko simple price endpoint (no API key required)
    const uri = 'https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd';

    // Retry configuration
    const maxAttempts = 3;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final resp = await _client
            .get(
              Uri.parse(uri),
              headers: {
                'Accept': 'application/json',
                // User-Agent helps avoid being silently blocked
                'User-Agent': 'iseefortune-app/1.0 (+https://example.com)',
              },
            )
            .timeout(const Duration(seconds: 5));

        // Retry only on rate limit or server errors
        if (resp.statusCode != 200) {
          if (resp.statusCode == 429 || (resp.statusCode >= 500 && resp.statusCode < 600)) {
            await _backoff(attempt);
            continue;
          }

          // Non-retryable error
          throw Exception('HTTP ${resp.statusCode}');
        }

        if (resp.body.isEmpty) {
          throw Exception('Empty response body');
        }

        // Parse JSON response
        final data = jsonDecode(resp.body);

        // Expected shape:
        // { "solana": { "usd": 123.45 } }
        final num? v = (data is Map) ? (data['solana'] is Map ? data['solana']['usd'] as num? : null) : null;

        if (v == null) {
          throw Exception('Missing solana.usd');
        }

        final price = v.toDouble();

        // Basic sanity checks
        if (price <= 0 || !price.isFinite) {
          throw Exception('Invalid price value: $price');
        }

        // Cache and return
        _cachedUsd = price;
        _cachedAt = DateTime.now();
        return price;
      } catch (_) {
        // On failure, apply backoff and retry (if attempts remain)
        await _backoff(attempt);
      }
    }

    // All attempts failed:
    // - Return stale cached value if available
    // - Otherwise return null so UI can hide USD
    return _cachedUsd;
  }

  /// Exponential backoff with jitter.
  ///
  /// - Base delay doubles each attempt
  /// - Capped to avoid excessively long waits
  /// - Jitter prevents thundering herd issues
  Future<void> _backoff(int attempt) async {
    final baseMs = math.min(1500 * (1 << (attempt - 1)), 6000);
    final jitter = math.Random().nextInt(400); // 0–399ms
    await Future.delayed(Duration(milliseconds: baseMs + jitter));
  }
}
