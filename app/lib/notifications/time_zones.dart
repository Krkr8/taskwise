import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Whether two IANA time zones show the same wall-clock time at every hour
/// boundary from [from] to [from] + [horizon] (a push plan's span): then a
/// plan built in one is right for the other, e.g. `Asia/Riyadh` and
/// `Asia/Baghdad`, or `Asia/Kolkata` and its old name `Asia/Calcutta`. An
/// unknown name is never the same as another.
bool sameTimeZones(
  String a,
  String b, {
  required DateTime from,
  Duration horizon = const Duration(days: 60),
}) {
  if (a == b) return true;
  if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
  final tz.Location first;
  final tz.Location second;
  try {
    first = tz.getLocation(a);
    second = tz.getLocation(b);
  } on tz.LocationNotFoundException {
    return false;
  }
  const hour = 3600 * 1000;
  final start = from.millisecondsSinceEpoch ~/ hour * hour;
  final end = start + horizon.inMilliseconds;
  for (var t = start; t <= end; t += hour) {
    if (first.timeZone(t).offset != second.timeZone(t).offset) return false;
  }
  return true;
}
