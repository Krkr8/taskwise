import 'sync_record.dart';

/// A saved place such as "Home" or "Work", used by location reminders.
final class Place implements SyncRecord {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.radiusMeters = defaultRadiusMeters,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory Place.fromJson(Map<String, Object?> json) => Place(
    id: json['id']! as String,
    name: json['name']! as String,
    latitude: (json['latitude']! as num).toDouble(),
    longitude: (json['longitude']! as num).toDouble(),
    address: json['address'] as String?,
    radiusMeters: json['radiusMeters'] as int? ?? defaultRadiusMeters,
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  /// Default location-reminder radius (SPEC.md section 3.3).
  static const int defaultRadiusMeters = 30;

  @override
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final int radiusMeters;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'radiusMeters': radiusMeters,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.address == address &&
      other.radiusMeters == radiusMeters &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    address,
    radiusMeters,
    updatedAt,
    deleted,
    updatedByDevice,
  );

  @override
  String toString() => 'Place($id, "$name")';
}
