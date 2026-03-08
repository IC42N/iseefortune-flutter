// ---------------------------------------------------------------------------
// Epoch/Date conversion + countdown helpers
// ---------------------------------------------------------------------------
// Anything here is about units, conversions, or “time remaining” logic.
// ---------------------------------------------------------------------------

String formatEta(Duration d) {
  if (d.inSeconds <= 0) return '—';

  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;

  if (h > 0) {
    return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString()}:${s.toString().padLeft(2, '0')}';
}

/// Converts epoch milliseconds to DateTime (nullable).
/// Use when your DB stores ms-based timestamps.
DateTime? dateTimeOrNullFromEpochMillis(int? epochMillis) {
  if (epochMillis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(epochMillis);
}

/// Converts epoch seconds to DateTime (nullable).
/// Use for Solana / typical UNIX timestamps.
DateTime? dateTimeOrNullFromEpochSeconds(int? epochSeconds) {
  if (epochSeconds == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
}

/// Returns how much time is left until a target epoch time (seconds).
/// - If the target is in the past, returns Duration.zero.
/// - Uses local device clock.
///
/// Great for epoch countdowns, cutoff timers, lock-in windows, etc.
Duration remainingUntilEpochSeconds(int targetEpochSeconds, {DateTime? nowOverride}) {
  final now = nowOverride ?? DateTime.now();
  final target = DateTime.fromMillisecondsSinceEpoch(targetEpochSeconds * 1000);
  final diff = target.difference(now);
  return diff.isNegative ? Duration.zero : diff;
}

/// Returns how much time has passed since a target epoch time (seconds).
/// - If the target is in the future, returns Duration.zero.
///
/// Useful for “how long since” when you want a Duration (not a string).
Duration elapsedSinceEpochSeconds(int epochSeconds, {DateTime? nowOverride}) {
  final now = nowOverride ?? DateTime.now();
  final target = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final diff = now.difference(target);
  return diff.isNegative ? Duration.zero : diff;
}

/// A UI-friendly countdown string like:
///   01:05  (MM:SS)
///   12:03  (MM:SS)
///
/// If you want HH:MM:SS later, we can add it.
/// This keeps V1 simple and readable.
String formatCountdownMMSS(Duration remaining) {
  final totalSec = remaining.inSeconds;
  final m = (totalSec ~/ 60).toString().padLeft(2, '0');
  final s = (totalSec % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Convenience helper:
/// Target epoch seconds -> "MM:SS" countdown string.
String countdownMMSSUntilEpochSeconds(int targetEpochSeconds, {DateTime? nowOverride}) {
  final remaining = remainingUntilEpochSeconds(targetEpochSeconds, nowOverride: nowOverride);
  return formatCountdownMMSS(remaining);
}
