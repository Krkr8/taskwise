import 'package:flutter/services.dart';

/// Location permission as iOS reports it.
enum LocationPermission {
  /// Not asked yet.
  notDetermined,

  /// Refused, or turned off in Settings.
  denied,

  /// Blocked by parental controls or a profile.
  restricted,

  /// "While Using the App": reminders can't fire with the app closed.
  whenInUse,

  /// "Always": what location reminders need.
  always,

  /// This device doesn't do location reminders (desktop).
  unsupported;

  static LocationPermission fromName(String? name) =>
      values.asNameMap()[name] ?? LocationPermission.notDetermined;
}

/// A location reminder as the phone watches it: the planned entry plus the
/// notification it shows, already in the app's language.
final class NativeLocationEntry {
  const NativeLocationEntry({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.arrive,
    required this.title,
    required this.body,
    required this.payload,
    required this.notificationId,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  /// True for "on arrive", false for "on leave".
  final bool arrive;
  final String title;
  final String body;

  /// Notification payload (see `NotificationPayload`), so taps, Done and
  /// Snooze work like for time reminders.
  final String payload;
  final int notificationId;

  Map<String, Object?> toMap() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radiusMeters,
    'trigger': arrive ? 'arrive' : 'leave',
    'title': title,
    'body': body,
    'payload': payload,
    'notificationId': notificationId,
  };

  @override
  bool operator ==(Object other) =>
      other is NativeLocationEntry &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters &&
      other.arrive == arrive &&
      other.title == title &&
      other.body == body &&
      other.payload == payload &&
      other.notificationId == notificationId;

  @override
  int get hashCode => Object.hash(
    id,
    latitude,
    longitude,
    radiusMeters,
    arrive,
    title,
    body,
    payload,
    notificationId,
  );
}

/// A position fix.
typedef LocationFix = ({double latitude, double longitude, double accuracy});

/// A monitored region, for the debug screen.
typedef MonitoredRegion = ({
  String id,
  double latitude,
  double longitude,
  double radius,
  String state,
});

/// What the phone is watching and what happened lately (debug screen).
final class LocationDebugState {
  const LocationDebugState({
    required this.permission,
    required this.entries,
    required this.regions,
    required this.events,
    this.lastFix,
    this.preciseActive = false,
  });

  factory LocationDebugState.fromMap(Map<Object?, Object?> map) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    final fix = map['lastFix'];
    return LocationDebugState(
      permission: LocationPermission.fromName(map['permission'] as String?),
      entries: (map['entries'] as int?) ?? 0,
      regions: [
        for (final r in (map['regions'] as List<Object?>? ?? const []))
          if (r is Map)
            (
              id: r['id'] as String? ?? '',
              latitude: d(r['latitude']),
              longitude: d(r['longitude']),
              radius: d(r['radius']),
              state: r['state'] as String? ?? 'unknown',
            ),
      ],
      events: [
        for (final e in (map['events'] as List<Object?>? ?? const []))
          if (e is String) e,
      ],
      lastFix: fix is Map
          ? (
              latitude: d(fix['latitude']),
              longitude: d(fix['longitude']),
              accuracy: d(fix['accuracy']),
            )
          : null,
      preciseActive: map['preciseActive'] == true,
    );
  }

  final LocationPermission permission;

  /// How many location reminders the phone knows about.
  final int entries;
  final List<MonitoredRegion> regions;

  /// Recent events, newest first ("12:01:05 enter region …").
  final List<String> events;
  final LocationFix? lastFix;

  /// Whether precise location updates are running right now.
  final bool preciseActive;
}

/// The phone side of location reminders. Only iOS watches places; other
/// platforms use [NoLocationPlatform].
abstract class LocationPlatform {
  /// Whether this device fires location reminders.
  bool get supported;

  /// Replaces the location reminders the phone watches.
  Future<void> setEntries(List<NativeLocationEntry> entries);

  Future<LocationPermission> permission();

  /// Asks for "While Using", then "Always". Returns the result.
  Future<LocationPermission> requestPermission();

  /// Opens Taskwise's page in the iOS Settings app.
  Future<void> openSettings();

  /// The current position, or null if unavailable.
  Future<LocationFix?> currentLocation();

  Future<LocationDebugState?> debugState();
}

/// Desktop: location reminders are edited here but never fire.
class NoLocationPlatform implements LocationPlatform {
  @override
  bool get supported => false;

  @override
  Future<void> setEntries(List<NativeLocationEntry> entries) async {}

  @override
  Future<LocationPermission> permission() async =>
      LocationPermission.unsupported;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.unsupported;

  @override
  Future<void> openSettings() async {}

  @override
  Future<LocationFix?> currentLocation() async => null;

  @override
  Future<LocationDebugState?> debugState() async => null;
}

/// iPhone: talks to `LocationRemindersPlugin.swift`.
class IosLocationPlatform implements LocationPlatform {
  static const _channel = MethodChannel('taskwise/location');

  @override
  bool get supported => true;

  @override
  Future<void> setEntries(List<NativeLocationEntry> entries) =>
      _channel.invokeMethod('setEntries', [for (final e in entries) e.toMap()]);

  @override
  Future<LocationPermission> permission() async => LocationPermission.fromName(
    await _channel.invokeMethod<String>('permissionStatus'),
  );

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.fromName(
        await _channel.invokeMethod<String>('requestPermission'),
      );

  @override
  Future<void> openSettings() => _channel.invokeMethod('openSettings');

  @override
  Future<LocationFix?> currentLocation() async {
    final map = await _channel.invokeMethod<Map<Object?, Object?>>(
      'currentLocation',
    );
    if (map == null) return null;
    return (
      latitude: (map['latitude']! as num).toDouble(),
      longitude: (map['longitude']! as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<LocationDebugState?> debugState() async {
    final map = await _channel.invokeMethod<Map<Object?, Object?>>(
      'debugState',
    );
    return map == null ? null : LocationDebugState.fromMap(map);
  }
}

/// Records calls (tests).
class FakeLocationPlatform implements LocationPlatform {
  FakeLocationPlatform({
    this.supported = true,
    this.current = LocationPermission.notDetermined,
    this.afterRequest = LocationPermission.always,
    this.fix,
  });

  @override
  final bool supported;
  LocationPermission current;
  LocationPermission afterRequest;
  LocationFix? fix;
  List<NativeLocationEntry>? lastEntries;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<void> setEntries(List<NativeLocationEntry> entries) async =>
      lastEntries = entries;

  @override
  Future<LocationPermission> permission() async => current;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return current = afterRequest;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<LocationFix?> currentLocation() async => fix;

  @override
  Future<LocationDebugState?> debugState() async => LocationDebugState(
    permission: current,
    entries: lastEntries?.length ?? 0,
    regions: [
      for (final e in lastEntries ?? const <NativeLocationEntry>[])
        (
          id: e.id,
          latitude: e.latitude,
          longitude: e.longitude,
          radius: 150.0,
          state: 'outside',
        ),
    ],
    events: const ['12:00:00 test event'],
  );
}
