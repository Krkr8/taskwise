import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/sync/record_codec.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

void main() {
  test('the outbox follows repeated writes, upserts included', () async {
    final db = openTestDatabase();
    final clock = FakeClock();
    final settings = SettingsRepository(db, deviceId: 'd', clock: clock.call);
    final tasks = TaskRepository(db, deviceId: 'd', clock: clock.call);
    final codec = RecordCodec(db);

    // Settings are written with an upsert; a second write used to fail
    // (OR REPLACE in a trigger is overridden by the outer statement).
    await settings.setWeekStart(WeekStart.monday);
    clock.advance();
    await settings.setWeekStart(WeekStart.saturday);
    await settings.setTheme(ThemePreference.dark); // device-only

    final task = await tasks.createTask(title: 'a');
    clock.advance();
    final record = (await codec.read('task', task.id))!;
    await codec.write('task', {...record, 'title': 'b'});
    await codec.write('task', {...record, 'title': 'c'});

    final rows = await db.select(db.syncOutbox).get();
    expect(
      {for (final r in rows) '${r.recordType}:${r.recordId}'},
      {'setting:week_start', 'task:${task.id}'},
    );
    expect((await tasks.getTask(task.id))!.title, 'c');
    await db.close();
  });

  test('every record type round-trips through the database', () async {
    final db = openTestDatabase();
    final codec = RecordCodec(db);
    for (final type in codec.types) {
      final record = _sample(type);
      await codec.write(type, record);
      expect(
        await codec.read(type, record['id']! as String),
        record,
        reason: type,
      );
    }
    await db.close();
  });
}

const _t = '2026-10-30T09:00:00.000Z';

Map<String, Object?> _sample(String type) {
  const sync = {'updatedAt': _t, 'deleted': false, 'updatedByDevice': 'dev-1'};
  return switch (type) {
    'task' => {
      'id': 't1',
      'title': 'Buy milk',
      'notes': 'n',
      'dueDate': '2026-11-02',
      'dueTimeMinutes': 570,
      'priority': 'high',
      'categoryId': 'c1',
      'done': false,
      'completedAt': null,
      'recurrenceRule': 'FREQ=DAILY',
      'notifyAllDevices': false,
      'createdAt': _t,
      ...sync,
    },
    'subtask' => {
      'id': 's1',
      'taskId': 't1',
      'title': 'x',
      'done': true,
      'sortOrder': 2,
      ...sync,
    },
    'category' => {
      'id': 'c1',
      'name': 'Home',
      'colorValue': 4283215696,
      ...sync,
    },
    'tag' => {'id': 'g1', 'name': 'errands', ...sync},
    'taskTag' => {'id': 'l1', 'taskId': 't1', 'tagId': 'g1', ...sync},
    'reminder' => {
      'id': 'r1',
      'taskId': 't1',
      'kind': 'location',
      'absoluteAt': null,
      'minutesBeforeDue': null,
      'placeId': null,
      'latitude': 33.3,
      'longitude': 44.4,
      'radiusMeters': 40,
      'trigger': 'leave',
      'label': 'Corner shop',
      ...sync,
    },
    'place' => {
      'id': 'p1',
      'name': 'Home',
      'latitude': 33.3,
      'longitude': 44.4,
      'address': 'Baghdad',
      'radiusMeters': 30,
      ...sync,
    },
    'setting' => {'id': 'week_start', 'value': 'monday', ...sync},
    'taskTargetDevice' => {
      'id': 'x1',
      'taskId': 't1',
      'deviceId': 'dev-2',
      ...sync,
    },
    _ => throw ArgumentError(type),
  };
}
