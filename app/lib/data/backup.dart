import 'dart:convert';

import 'package:taskwise_shared/taskwise_shared.dart';

import '../sync/record_codec.dart';
import '../version.dart';
import 'db/app_database.dart';

/// What an import did.
typedef ImportReport = ({int added, int updated, int kept, int skipped});

/// Why a file can't be imported.
enum BackupProblem {
  /// Not a Taskwise backup (or not JSON at all).
  notABackup,

  /// Made by a newer Taskwise that uses a format this one doesn't know.
  tooNew,
}

final class BackupException implements Exception {
  const BackupException(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupException(${problem.name})';
}

/// JSON backups of everything that syncs: tasks, subtasks, categories,
/// tags, reminders, places, device choices and synced settings.
///
/// The records are the same JSON the sync uses (the shared models'
/// `toJson`), so a backup from any device can be imported on any other.
///
/// Import merges: a record is added when it's missing, updated when the
/// backup's copy is newer, and kept when this device's copy is newer. A
/// record deleted here but alive in the backup comes back (that's what
/// restoring a backup is for). Everything an import changes is synced to
/// the other devices.
class Backup {
  Backup(this.db, {required this.deviceId, DateTime Function()? clock})
    : _codec = RecordCodec(db),
      _clock = clock ?? DateTime.now;

  static const format = 'taskwise-backup';
  static const version = 1;

  /// Parents before children, so a file is readable from top to bottom.
  static const types = [
    'setting',
    'category',
    'tag',
    'place',
    'task',
    'subtask',
    'taskTag',
    'reminder',
    'taskTargetDevice',
  ];

  final AppDatabase db;
  final String deviceId;
  final RecordCodec _codec;
  final DateTime Function() _clock;

  /// The whole backup as pretty JSON. Deleted records are left out.
  Future<String> export() async {
    final records = <Map<String, Object?>>[];
    for (final type in types) {
      for (final id in (await _codec.ids(type)).toList()..sort()) {
        final record = await _codec.read(type, id);
        if (record == null || record['deleted'] == true) continue;
        records.add({'type': type, 'record': record});
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'app': appVersion,
      'exportedAt': JsonFields.dateTime(_clock().toUtc()),
      'records': records,
    });
  }

  /// Merges a backup made by [export] into this device's data.
  Future<ImportReport> import(String json) async {
    final records = _parse(json);
    var added = 0, updated = 0, kept = 0, skipped = 0;
    await db.transaction(() async {
      for (final item in records) {
        if (item is! Map ||
            item['type'] is! String ||
            item['record'] is! Map ||
            !_codec.knows(item['type'] as String)) {
          skipped++;
          continue;
        }
        final type = item['type'] as String;
        final record = Map<String, Object?>.from(item['record'] as Map);
        try {
          final id = record['id']! as String;
          final incoming = (
            updatedAt: JsonFields.parseRequiredDateTime(record['updatedAt']),
            updatedByDevice: record['updatedByDevice'] as String?,
          );
          if (record['deleted'] == true) {
            skipped++;
            continue;
          }
          final current = await _codec.read(type, id);
          if (current == null) {
            await _codec.write(type, record);
            added++;
          } else if (current['deleted'] == true) {
            // Deleted here since the backup: bring it back, newer than the
            // deletion so the other devices get it back too.
            await _codec.write(type, {
              ...record,
              'updatedAt': JsonFields.dateTime(_newerThan(current)),
              'updatedByDevice': deviceId,
            });
            updated++;
          } else if (winsOver(incoming, await _codec.stamp(type, id))) {
            await _codec.write(type, record);
            updated++;
          } else {
            kept++;
          }
        } on Object {
          // A damaged record: leave it out, import the rest.
          skipped++;
        }
      }
    });
    return (added: added, updated: updated, kept: kept, skipped: skipped);
  }

  DateTime _newerThan(Map<String, Object?> current) {
    final now = _clock().toUtc();
    final stored = JsonFields.parseRequiredDateTime(current['updatedAt']);
    return now.isAfter(stored)
        ? now
        : stored.add(const Duration(milliseconds: 1));
  }

  static List<Object?> _parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupException(BackupProblem.notABackup);
    }
    if (decoded is! Map ||
        decoded['format'] != format ||
        decoded['version'] is! int ||
        decoded['records'] is! List) {
      throw const BackupException(BackupProblem.notABackup);
    }
    if ((decoded['version'] as int) > version) {
      throw const BackupException(BackupProblem.tooNew);
    }
    return decoded['records'] as List<Object?>;
  }
}
