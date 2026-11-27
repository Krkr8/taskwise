import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// This device's IANA time zone (e.g. `Europe/Berlin`), or null when it
/// can't be read. Tests override it.
final deviceTimeZoneProvider = FutureProvider<String?>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    return null;
  }
});
