import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/db/app_database.dart';
import '../data/repositories/settings_repository.dart';
import 'record_codec.dart';
import 'sync_api.dart';

/// What one sync did.
typedef SyncReport = ({int pushed, int pulled});

/// Syncs the local database with the server (SPEC.md section 4,
/// docs/sync-api.md): push the outbox, then pull until up to date, then
/// refresh the device list.
///
/// Errors from [SyncApi] are passed on; the caller decides what they mean
/// for the status (offline, signed out...). Every step is safe to repeat,
/// so a sync cut short just continues next time.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.api,
    required this.deviceId,
    this.pushBatch = SyncApi.maxPushChanges,
    this.pullLimit = 500,
  }) : _codec = RecordCodec(db),
       _settings = SettingsRepository(db, deviceId: deviceId);

  final AppDatabase db;
  final SyncApi api;
  final String deviceId;
  final RecordCodec _codec;
  final SettingsRepository _settings;

  /// Changes per push request, and per pull page.
  final int pushBatch;
  final int pullLimit;

  /// Rounds of pushing per sync, so a stream of edits can't keep it busy.
  static const _maxPushRounds = 20;

  Future<SyncReport> sync() async {
    final pushed = await push();
    final pulled = await pull();
    await refreshDevices();
    return (pushed: pushed, pulled: pulled);
  }

  // ------------------------------------------------------------------ push

  /// Sends queued local changes; returns how many were sent.
  Future<int> push() async {
    var sent = 0;
    for (var round = 0; round < _maxPushRounds; round++) {
      final entries =
          await (db.select(db.syncOutbox)
                ..orderBy([(o) => OrderingTerm.asc(o.updatedAt)])
                ..limit(pushBatch))
              .get();
      if (entries.isEmpty) break;

      final batch = <(OutboxRow, SyncChange)>[];
      for (final entry in entries) {
        final record = _codec.knows(entry.recordType)
            ? await _codec.read(entry.recordType, entry.recordId)
            : null;
        if (record == null) {
          // The row is gone (or of a type this version doesn't sync).
          await _dequeue(entry);
        } else {
          batch.add((entry, (type: entry.recordType, record: record)));
        }
      }
      if (batch.isNotEmpty) {
        await api.push([for (final (_, change) in batch) change]);
        // Only entries whose row is still the version that was sent: an
        // edit made meanwhile stays queued for the next round.
        await db.transaction(() async {
          for (final (entry, _) in batch) {
            await _dequeue(entry);
          }
        });
        sent += batch.length;
      }
      if (entries.length < pushBatch) break;
    }
    return sent;
  }

  Future<void> _dequeue(OutboxRow entry) =>
      (db.delete(db.syncOutbox)..where(
            (o) =>
                o.recordType.equals(entry.recordType) &
                o.recordId.equals(entry.recordId) &
                o.updatedAt.equals(entry.updatedAt),
          ))
          .go();

  // ------------------------------------------------------------------ pull

  /// Fetches the server's changes since the last pull and applies them;
  /// returns how many were applied. On `410 resync_required` it starts
  /// over from the beginning (see [_fullResync]).
  Future<int> pull() async {
    final since = (await _settings.getSyncSettings()).seq;
    try {
      return await _pullFrom(since);
    } on SyncHttpException catch (e) {
      if (e.code != 'resync_required') rethrow;
      return _fullResync();
    }
  }

  Future<int> _pullFrom(int since, {Set<(String, String)>? seen}) async {
    var applied = 0;
    var cursor = since;
    while (true) {
      final page = await api.pull(since: cursor, limit: pullLimit);
      await db.transaction(() async {
        for (final change in page.changes) {
          seen?.add((change.type, change.record['id']! as String));
          if (await _apply(change.type, change.record)) applied++;
        }
        await _settings.setSyncSeq(page.nextSince);
      });
      cursor = page.nextSince;
      if (!page.hasMore) return applied;
    }
  }

  /// Applies one pulled record if it beats the local row (last write
  /// wins). A local row that is newer is an edit not pushed yet: it stays,
  /// and goes to the server on the next push.
  Future<bool> _apply(String type, Map<String, Object?> record) async {
    if (!_codec.knows(type)) return false; // From a newer app version.
    final id = record['id']! as String;
    final incoming = (
      updatedAt: JsonFields.parseRequiredDateTime(record['updatedAt']),
      updatedByDevice: record['updatedByDevice'] as String?,
    );
    if (!winsOver(incoming, await _codec.stamp(type, id))) return false;
    await _codec.write(type, record);
    // The write queued it (triggers); the server already has it.
    await (db.delete(
      db.syncOutbox,
    )..where((o) => o.recordType.equals(type) & o.recordId.equals(id))).go();
    return true;
  }

  /// Pulls everything from the start, then removes local records the
  /// server no longer has (purged while this device was away), except
  /// ones still waiting to be pushed.
  Future<int> _fullResync() async {
    final seen = <(String, String)>{};
    final applied = await _pullFrom(0, seen: seen);
    await db.transaction(() async {
      final queued = {
        for (final o in await db.select(db.syncOutbox).get())
          (o.recordType, o.recordId),
      };
      for (final type in _codec.types) {
        for (final id in await _codec.ids(type)) {
          if (!seen.contains((type, id)) && !queued.contains((type, id))) {
            await _codec.delete(type, id);
          }
        }
      }
    });
    return applied;
  }

  // --------------------------------------------------------------- devices

  /// Replaces the local device list with the server's (the server owns
  /// devices; revoked ones come back as `deleted`).
  Future<void> refreshDevices() async {
    final devices = await api.devices();
    await db.transaction(() async {
      for (final d in devices) {
        await db
            .into(db.devices)
            .insertOnConflictUpdate(
              DevicesCompanion.insert(
                id: d.id,
                name: d.name,
                type: d.type,
                lastSeenAt: Value(d.lastSeenAt),
                updatedAt: d.updatedAt,
                deleted: Value(d.deleted),
                updatedByDevice: Value(d.updatedByDevice),
              ),
            );
      }
      final known = {for (final d in devices) d.id, deviceId};
      await (db.delete(db.devices)..where((d) => d.id.isNotIn(known))).go();
    });
  }
}
