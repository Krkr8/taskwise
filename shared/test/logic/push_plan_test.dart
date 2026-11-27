import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 10, 1);

Task _task(
  String id, {
  LocalDate? due,
  int? time,
  String? rule,
  bool done = false,
}) => Task(
  id: id,
  title: 'Task $id',
  dueDate: due,
  dueTimeMinutes: time,
  recurrenceRule: rule,
  done: done,
  createdAt: _at,
  updatedAt: _at,
);

Reminder _before(String id, String taskId, int minutes) => Reminder(
  id: id,
  taskId: taskId,
  kind: ReminderKind.time,
  minutesBeforeDue: minutes,
  updatedAt: _at,
);

/// Tuesday 2026-10-20, 08:00 local.
final _now = DateTime(2026, 10, 20, 8);

List<PushPlanItem> _build(
  List<Task> tasks,
  List<Reminder> reminders, {
  bool Function(Task)? targeted,
  int limit = 500,
}) => buildPushPlan(
  tasks: tasks,
  reminders: reminders,
  notifiesDevice: targeted ?? (_) => true,
  now: _now,
  body: (p) => 'body ${p.taskId}',
  limit: limit,
);

void main() {
  test(
    'a task due tomorrow 09:00 with a 30-minute reminder gives one item',
    () {
      final items = _build(
        [_task('a', due: LocalDate(2026, 10, 21), time: 9 * 60)],
        [_before('r', 'a', 30)],
      );
      expect(items, hasLength(1));
      expect(items.single.fireAt, DateTime(2026, 10, 21, 8, 30).toUtc());
      expect(items.single.fireAt.isUtc, isTrue);
      expect(items.single.taskId, 'a');
      expect(items.single.title, 'Task a');
      expect(items.single.body, 'body a');
      expect(items.single.key, isNotEmpty);
    },
  );

  test('a task not targeted at the device gives nothing', () {
    expect(
      _build(
        [_task('a', due: LocalDate(2026, 10, 21), time: 9 * 60)],
        [_before('r', 'a', 30)],
        targeted: (_) => false,
      ),
      isEmpty,
    );
  });

  test('a done task gives nothing', () {
    expect(
      _build(
        [_task('a', due: LocalDate(2026, 10, 21), time: 9 * 60, done: true)],
        [_before('r', 'a', 30)],
      ),
      isEmpty,
    );
  });

  test('a daily repeat gives one item a day for 60 days, capped by limit', () {
    final tasks = [
      _task(
        'a',
        due: LocalDate(2026, 10, 21),
        time: 9 * 60,
        rule: 'DTSTART=20261021;FREQ=DAILY',
      ),
    ];
    final items = _build(tasks, [_before('r', 'a', 0)]);
    expect(items.length, inInclusiveRange(59, 61));
    expect(
      items.map((i) => i.fireAt).toList(),
      [...items.map((i) => i.fireAt)]..sort(),
    );
    expect(_build(tasks, [_before('r', 'a', 0)], limit: 5), hasLength(5));
  });

  test('toJson writes fireAt as UTC milliseconds and fromJson reads it', () {
    final item = PushPlanItem(
      key: '1',
      fireAt: DateTime.utc(2026, 10, 21, 5, 30),
      taskId: 'a',
      title: 'T',
      body: 'B',
    );
    final json = item.toJson();
    expect(
      json['fireAt'],
      DateTime.utc(2026, 10, 21, 5, 30).millisecondsSinceEpoch,
    );
    final back = PushPlanItem.fromJson(json);
    expect(back.fireAt, item.fireAt);
    expect(back.fireAt.isUtc, isTrue);
    expect(back.key, '1');
    expect(back.title, 'T');
    expect(back.body, 'B');
  });

  test('pushPlanHash is stable and changes when a fireAt changes', () {
    PushPlanItem item(String key, int minute) => PushPlanItem(
      key: key,
      fireAt: DateTime.utc(2026, 10, 21, 5, minute),
      taskId: 'a',
      title: 'T',
      body: 'B',
    );
    final a = [item('1', 0), item('2', 30)];
    expect(pushPlanHash(a), pushPlanHash([item('1', 0), item('2', 30)]));
    expect(pushPlanHash(a), pushPlanHash([a[1], a[0]]));
    expect(pushPlanHash(a), isNot(pushPlanHash([item('1', 0), item('2', 31)])));
  });
}
