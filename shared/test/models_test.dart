import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 10, 20, 8, 30);
final _t1 = DateTime.utc(2026, 10, 21, 9);

void main() {
  group('JSON round-trip', () {
    void roundTrip<T>(
      T value,
      Map<String, Object?> Function(T) toJson,
      T Function(Map<String, Object?>) fromJson,
    ) {
      expect(fromJson(toJson(value)), value);
    }

    test('Task with every field set', () {
      roundTrip(
        Task(
          id: 'task-1',
          title: 'Buy milk',
          notes: 'Two bottles\n- skimmed',
          dueDate: LocalDate(2026, 10, 21),
          dueTimeMinutes: 9 * 60 + 30,
          priority: Priority.high,
          categoryId: 'cat-1',
          done: true,
          completedAt: _t1,
          recurrenceRule: 'FREQ=WEEKLY',
          notifyAllDevices: false,
          createdAt: _t0,
          updatedAt: _t1,
          deleted: true,
          updatedByDevice: 'dev-1',
        ),
        (v) => v.toJson(),
        Task.fromJson,
      );
    });

    test('Task with only required fields', () {
      final task = Task(
        id: 'task-2',
        title: 'Minimal',
        createdAt: _t0,
        updatedAt: _t0,
      );
      roundTrip(task, (v) => v.toJson(), Task.fromJson);
      expect(task.notifyAllDevices, isTrue);
      expect(task.priority, Priority.none);
    });

    test('Subtask, Category, Tag, TaskTag', () {
      roundTrip(
        Subtask(
          id: 's',
          taskId: 't',
          title: 'Step',
          done: true,
          sortOrder: 3,
          updatedAt: _t0,
        ),
        (v) => v.toJson(),
        Subtask.fromJson,
      );
      roundTrip(
        Category(id: 'c', name: 'Work', colorValue: 0xFF2E7D32, updatedAt: _t0),
        (v) => v.toJson(),
        Category.fromJson,
      );
      roundTrip(
        Tag(id: 'g', name: 'errand', updatedAt: _t0, updatedByDevice: 'd'),
        (v) => v.toJson(),
        Tag.fromJson,
      );
      roundTrip(
        TaskTag(id: 'l', taskId: 't', tagId: 'g', updatedAt: _t0),
        (v) => v.toJson(),
        TaskTag.fromJson,
      );
    });

    test('Place, Device, TaskTargetDevice', () {
      roundTrip(
        Place(
          id: 'p',
          name: 'Home',
          latitude: 33.3152,
          longitude: 44.3661,
          address: 'Baghdad',
          radiusMeters: 50,
          updatedAt: _t0,
        ),
        (v) => v.toJson(),
        Place.fromJson,
      );
      roundTrip(
        Device(
          id: 'd',
          name: 'Fedora Laptop',
          type: DeviceType.linux,
          lastSeenAt: _t1,
          updatedAt: _t0,
        ),
        (v) => v.toJson(),
        Device.fromJson,
      );
      roundTrip(
        TaskTargetDevice(id: 'x', taskId: 't', deviceId: 'd', updatedAt: _t0),
        (v) => v.toJson(),
        TaskTargetDevice.fromJson,
      );
    });

    test('Reminder (time and location)', () {
      roundTrip(
        Reminder(
          id: 'r1',
          taskId: 't',
          kind: ReminderKind.time,
          minutesBeforeDue: 15,
          updatedAt: _t0,
        ),
        (v) => v.toJson(),
        Reminder.fromJson,
      );
      roundTrip(
        Reminder(
          id: 'r2',
          taskId: 't',
          kind: ReminderKind.location,
          placeId: 'p',
          latitude: 33.3,
          longitude: 44.4,
          radiusMeters: 30,
          trigger: LocationTrigger.leave,
          updatedAt: _t0,
        ),
        (v) => v.toJson(),
        Reminder.fromJson,
      );
    });

    test('timestamps are serialised as UTC', () {
      final local = DateTime(2026, 10, 20, 12);
      final task = Task(
        id: 't',
        title: 'x',
        createdAt: local,
        updatedAt: local,
      );
      final json = task.toJson();
      expect(json['createdAt'], endsWith('Z'));
      expect(Task.fromJson(json).createdAt, local.toUtc());
    });
  });

  group('Task', () {
    final base = Task(id: 't', title: 'x', createdAt: _t0, updatedAt: _t0);

    test('copyWith can clear nullable fields', () {
      final dated = base.copyWith(
        dueDate: () => LocalDate(2026, 10, 21),
        dueTimeMinutes: () => 600,
        categoryId: () => 'c',
      );
      expect(dated.dueAt, DateTime(2026, 10, 21, 10));
      final cleared = dated.copyWith(
        dueDate: () => null,
        dueTimeMinutes: () => null,
        categoryId: () => null,
      );
      expect(cleared.dueDate, isNull);
      expect(cleared.dueTimeMinutes, isNull);
      expect(cleared.categoryId, isNull);
      expect(cleared, base);
    });

    test('isAllDay', () {
      expect(base.isAllDay, isFalse);
      expect(
        base.copyWith(dueDate: () => LocalDate(2026, 1, 1)).isAllDay,
        isTrue,
      );
      expect(
        base
            .copyWith(
              dueDate: () => LocalDate(2026, 1, 1),
              dueTimeMinutes: () => 60,
            )
            .isAllDay,
        isFalse,
      );
    });

    test('validateTitle trims and rejects blank titles', () {
      expect(Task.validateTitle('  Call mum \n'), 'Call mum');
      expect(() => Task.validateTitle('   '), throwsArgumentError);
    });

    test('enum parsing falls back to defaults', () {
      expect(Priority.fromName('bogus'), Priority.none);
      expect(WeekStart.fromName(null), WeekStart.sunday);
      expect(DeviceType.fromName('linux'), DeviceType.linux);
    });
  });
}
