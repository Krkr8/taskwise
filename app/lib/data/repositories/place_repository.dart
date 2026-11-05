import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../db/app_database.dart';
import 'repository_base.dart';

/// Reads and writes saved places ("Home", "Work") for location reminders.
class PlaceRepository extends RepositoryBase {
  PlaceRepository(super.db, {required super.deviceId, super.clock});

  /// All non-deleted places, alphabetically.
  Stream<List<Place>> watchPlaces() =>
      (db.select(db.places)
            ..where((p) => p.deleted.not())
            ..orderBy([
              (p) => OrderingTerm.asc(p.name.collate(Collate.noCase)),
            ]))
          .watch()
          .map((rows) => rows.map(toPlace).toList());

  Future<Place?> getPlace(String id) async {
    final row = await (db.select(
      db.places,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null || row.deleted ? null : toPlace(row);
  }

  Future<Place> createPlace({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    int radiusMeters = Place.defaultRadiusMeters,
  }) async {
    final place = Place(
      id: newId(),
      name: Task.validateTitle(name),
      latitude: latitude,
      longitude: longitude,
      address: address,
      radiusMeters: radiusMeters,
      updatedAt: now(),
      updatedByDevice: deviceId,
    );
    await db.into(db.places).insert(toCompanion(place));
    return place;
  }

  Future<void> updatePlace(
    String id, {
    String? name,
    double? latitude,
    double? longitude,
    String? Function()? address,
    int? radiusMeters,
  }) => (db.update(db.places)..where((p) => p.id.equals(id))).write(
    PlacesCompanion(
      name: name == null
          ? const Value.absent()
          : Value(Task.validateTitle(name)),
      latitude: Value.absentIfNull(latitude),
      longitude: Value.absentIfNull(longitude),
      address: address == null ? const Value.absent() : Value(address()),
      radiusMeters: Value.absentIfNull(radiusMeters),
      updatedAt: Value(now()),
      updatedByDevice: Value(deviceId),
    ),
  );

  /// Tombstones a place. Reminders that used it keep working: they get the
  /// place's position and name as their own.
  Future<void> deletePlace(String id) => db.transaction(() async {
    final place = await getPlace(id);
    if (place == null) return;
    final at = now();
    await (db.update(db.places)..where((p) => p.id.equals(id))).write(
      PlacesCompanion(
        deleted: const Value(true),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
    await (db.update(
      db.reminders,
    )..where((r) => r.placeId.equals(id) & r.deleted.not())).write(
      RemindersCompanion(
        placeId: const Value(null),
        latitude: Value(place.latitude),
        longitude: Value(place.longitude),
        label: Value(place.name),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
  });

  static Place toPlace(PlaceRow row) => Place(
    id: row.id,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    address: row.address,
    radiusMeters: row.radiusMeters,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );

  static PlacesCompanion toCompanion(Place p) => PlacesCompanion.insert(
    id: p.id,
    name: p.name,
    latitude: p.latitude,
    longitude: p.longitude,
    address: Value(p.address),
    radiusMeters: Value(p.radiusMeters),
    updatedAt: p.updatedAt,
    deleted: Value(p.deleted),
    updatedByDevice: Value(p.updatedByDevice),
  );
}
