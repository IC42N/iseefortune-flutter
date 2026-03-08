import 'package:intl/intl.dart';

String formatShortCountdownShort(int seconds) {
  if (seconds <= 0) return 'Closed';

  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;

  if (h >= 24) {
    final d = h ~/ 24;
    final remH = h % 24;
    return '${d}d ${remH}h';
  }

  if (h > 0) {
    final parts = <String>['${h}h', if (m > 0) '${m}m', if (s > 0) '${s}s'];
    return parts.join(' ');
  }

  final parts = <String>[if (m > 0) '${m}m', if (s > 0) '${s}s'];

  return parts.isEmpty ? '0s' : parts.join(' ');
}

String formatShortCountdown(int seconds) {
  if (seconds <= 0) return '0h 00m 00s';

  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;

  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');

  if (h > 0) {
    return '${hh}h ${mm}m ${ss}s';
  }

  return '${mm}m ${ss}s';
}

/// ---------------------------------------------------------------------------
/// Formatting helpers (Date/Time -> String)
/// ---------------------------------------------------------------------------
/// Keep these "pure" (no network / no storage).
/// Inputs are explicit about units: epochSeconds vs epochMillis.
/// ---------------------------------------------------------------------------

/// Converts a duration (in seconds) into a short, human-readable string.
/// Examples:
///   45   -> "45 sec"
///   120  -> "2 min"
///   125  -> "2 min 5 sec"
///
/// Great for countdown displays or “time remaining” labels.
String formatDurationReadableSeconds(int seconds) {
  if (seconds < 60) {
    return "$seconds sec";
  } else if (seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return "$minutes min";
  } else {
    final minutes = seconds ~/ 60;
    final remainingSec = seconds % 60;
    return "$minutes min $remainingSec sec";
  }
}

/// Formats a UNIX timestamp (epoch seconds) into a relative "time ago" string.
/// Examples:
///   < 60s     -> "just now"
///   < 60 min  -> "5 mins ago"
///   < 24 hr   -> "2 hrs ago"
///   >= 24 hr  -> "Jul 14"
///
/// Perfect for feeds / history lists / activity logs.
String formatTimeAgoFromEpochSeconds(int epochSeconds) {
  final now = DateTime.now();
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final diff = now.difference(date);

  if (diff.inSeconds < 60) {
    return "just now";
  } else if (diff.inMinutes < 60) {
    return "${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago";
  } else if (diff.inHours < 24) {
    return "${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago";
  } else {
    // After 24 hours, show a compact US-style date (no year).
    return DateFormat('MMM d').format(date);
  }
}

/// Formats a UNIX timestamp (epoch seconds) into a full date + time string.
/// Example: "July 14, 2025 3:45 PM"
///
/// Best for detail views / modals / tooltips.
String formatFullDateTimeFromEpochSeconds(int epochSeconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return DateFormat('MMMM d, yyyy h:mm a').format(date);
}

/// Formats a UNIX timestamp (epoch seconds) into a full date only.
/// Example: "July 14, 2025"
String formatFullDateFromEpochSeconds(int epochSeconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return DateFormat('MMMM d, yyyy').format(date);
}

/// Formats a UNIX timestamp (epoch seconds) into a time-only string.
/// Example: "3:45 PM"
String formatTimeFromEpochSeconds(int epochSeconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return DateFormat('h:mm a').format(date);
}

/// Formats a delay (in seconds) into a short readable string.
/// Examples:
///   45  -> "45s"
///   90  -> "1 min 30s"
///   120 -> "2 min"
///
/// Used for delay settings, confirmations, etc.
String formatDelaySeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final leftover = seconds % 60;

  if (minutes > 0) {
    return leftover > 0 ? "$minutes min ${leftover}s" : "$minutes min";
  }
  return "${leftover}s";
}

/// Formats a Dart Duration into a compact string with adaptive units.
/// Examples:
///   < 1s     -> "250 ms"
///   < 1 min  -> "45s"
///   >= 1 min -> "2m 15s"
///
/// Great for debug logs or performance UI.
String formatDurationShort(Duration d) => d.inSeconds < 1
    ? '${d.inMilliseconds} ms'
    : d.inMinutes < 1
    ? '${d.inSeconds}s'
    : '${d.inMinutes}m ${d.inSeconds % 60}s';

/// Cached date formatter for local epoch seconds.
/// Example output: "7/14/25 3:45 PM"
final DateFormat _epochSecondsLocalFmt = DateFormat('M/d/y h:mm a');

/// Formats epoch seconds as a localized date/time string.
/// Good for “submitted at”, “finalized at”, etc.
String formatEpochSecondsLocal(int epochSeconds) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000).toLocal();
  return _epochSecondsLocalFmt.format(dt);
}
