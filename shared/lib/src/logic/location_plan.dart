import 'dart:math' as math;

import '../models/enums.dart';
import '../models/place.dart';
import '../models/reminder.dart';
import '../models/task.dart';

/// A location reminder ready for the phone to watch: where, how close,
/// arrive or leave, and what the notification says about it.
final class LocationReminderEntry {
  const LocationReminderEntry({
    required this.reminderId,
    required this.taskId,
    required this.taskTitle,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.trigger,
    this.placeName,
  });

  /// The reminder's id (also the monitored region's id on iOS).
  final String reminderId;
  final String taskId;
  final String taskTitle;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final LocationTrigger trigger;

  /// The saved place's name, or the reminder's own label; null for a
  /// dropped pin without a name.
  final String? placeName;

  @override
  bool operator ==(Object other) =>
      other is LocationReminderEntry &&
      other.reminderId == reminderId &&
      other.taskId == taskId &&
      other.taskTitle == taskTitle &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters &&
      other.trigger == trigger &&
      other.placeName == placeName;

  @override
  int get hashCode => Object.hash(
    reminderId,
    taskId,
    taskTitle,
    latitude,
    longitude,
    radiusMeters,
    trigger,
    placeName,
  );

  @override
  String toString() =>
      'LocationReminderEntry($reminderId, ${trigger.name} '
      '$latitude,$longitude r=$radiusMeters)';
}

/// Smallest and largest radius a location reminder can have (SPEC.md 3.3).
const minLocationRadius = 30;
const maxLocationRadius = 500;

/// The location reminders this device should watch.
///
/// [tasks] are the tasks that notify on this device (the caller filters by
/// "Notify on"). Done and deleted tasks are skipped, and so are reminders
/// whose saved place was deleted. A reminder that points to a saved place
/// uses the place's current position, so moving "Home" moves its
/// reminders. Location reminders fire every time while the task is open,
/// so repeats need no special handling.
List<LocationReminderEntry> planLocationReminders({
  required Iterable<Task> tasks,
  required Iterable<Reminder> reminders,
  required Iterable<Place> places,
}) {
  final open = {
    for (final t in tasks)
      if (!t.done && !t.deleted) t.id: t,
  };
  final placesById = {
    for (final p in places)
      if (!p.deleted) p.id: p,
  };
  final entries = <LocationReminderEntry>[];
  for (final r in reminders) {
    if (r.deleted || r.kind != ReminderKind.location) continue;
    final task = open[r.taskId];
    if (task == null) continue;
    final double latitude;
    final double longitude;
    String? name = r.label;
    if (r.placeId case final placeId?) {
      final place = placesById[placeId];
      if (place == null) continue;
      latitude = place.latitude;
      longitude = place.longitude;
      name = place.name;
    } else if ((r.latitude, r.longitude) case (final lat?, final lon?)) {
      latitude = lat;
      longitude = lon;
    } else {
      continue;
    }
    entries.add(
      LocationReminderEntry(
        reminderId: r.id,
        taskId: task.id,
        taskTitle: task.title,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: (r.radiusMeters ?? Place.defaultRadiusMeters).clamp(
          minLocationRadius,
          maxLocationRadius,
        ),
        trigger: r.trigger ?? LocationTrigger.arrive,
        placeName: name,
      ),
    );
  }
  entries.sort((a, b) => a.reminderId.compareTo(b.reminderId));
  return entries;
}

/// Great-circle distance in metres between two points (haversine).
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371008.8;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
}
