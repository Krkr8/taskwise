import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 11, 1);
final _today = LocalDate(2026, 11, 12);

Task task(
  String title, {
  LocalDate? due,
  int? time,
  bool done = false,
  bool deleted = false,
}) => Task(
  id: title,
  title: title,
  dueDate: due,
  dueTimeMinutes: time,
  done: done,
  deleted: deleted,
  createdAt: _at,
  updatedAt: _at,
);

void main() {
  group('AssistantInboxEntry', () {
    test('round-trips through JSON', () {
      final entry = AssistantInboxEntry(
        id: '0199a3c0-0000-7000-8000-000000000001',
        title: '  Buy milk ',
        notes: 'Two litres',
        dueDate: LocalDate(2026, 11, 13),
        dueTimeMinutes: 17 * 60,
        createdAt: DateTime.utc(2026, 11, 12, 9, 30),
      );
      expect(entry.title, 'Buy milk');
      final back = AssistantInboxEntry.tryFromJson(entry.toJson())!;
      expect(back.id, entry.id);
      expect(back.title, 'Buy milk');
      expect(back.notes, 'Two litres');
      expect(back.dueDate, LocalDate(2026, 11, 13));
      expect(back.dueTimeMinutes, 17 * 60);
      expect(back.createdAt, DateTime.utc(2026, 11, 12, 9, 30));
    });

    test('reads what the iPhone writes', () {
      final entry = AssistantInboxEntry.tryFromJson({
        'id': 'a',
        'title': 'Call mum',
        'dueDate': '2026-11-14',
        'createdAt': '2026-11-12T09:30:00Z',
      })!;
      expect(entry.dueDate, LocalDate(2026, 11, 14));
      expect(entry.dueTimeMinutes, isNull);
      expect(entry.notes, '');
      expect(entry.toJson().containsKey('notes'), isFalse);
    });

    test('drops a time without a date', () {
      final entry = AssistantInboxEntry.tryFromJson({
        'id': 'a',
        'title': 'x',
        'dueTimeMinutes': 60,
        'createdAt': '2026-11-12T09:30:00Z',
      })!;
      expect(entry.dueTimeMinutes, isNull);
    });

    test('rejects malformed entries', () {
      for (final bad in <Object?>[
        null,
        'text',
        {'title': 'no id', 'createdAt': '2026-11-12T09:30:00Z'},
        {'id': 'a', 'title': '   ', 'createdAt': '2026-11-12T09:30:00Z'},
        {'id': 'a', 'title': 'x'},
        {'id': 'a', 'title': 'x', 'createdAt': 'yesterday'},
        {
          'id': 'a',
          'title': 'x',
          'dueDate': '2026-13-01',
          'createdAt': '2026-11-12T09:30:00Z',
        },
        {
          'id': 'a',
          'title': 'x',
          'dueDate': '2026-11-12',
          'dueTimeMinutes': 1440,
          'createdAt': '2026-11-12T09:30:00Z',
        },
      ]) {
        expect(AssistantInboxEntry.tryFromJson(bad), isNull, reason: '$bad');
      }
    });

    test('parseAssistantInbox skips bad entries and keeps the rest', () {
      final list = parseAssistantInbox([
        {'id': 'a', 'title': 'One', 'createdAt': '2026-11-12T09:30:00Z'},
        {'id': 'b'},
        {'id': 'c', 'title': 'Three', 'createdAt': '2026-11-12T09:31:00Z'},
      ]);
      expect([for (final e in list) e.id], ['a', 'c']);
      expect(parseAssistantInbox({'not': 'a list'}), isEmpty);
    });
  });

  group('buildAssistantSnapshot', () {
    test('lists open overdue and upcoming tasks, soonest first', () {
      final snapshot = buildAssistantSnapshot([
        task('Later', due: _today.addDays(3)),
        task('Timed', due: _today, time: 9 * 60),
        task('All day', due: _today),
        task('Overdue', due: _today.addDays(-2)),
        task('Too far', due: _today.addDays(8)),
        task('No date'),
        task('Done', due: _today, done: true),
        task('Deleted', due: _today, deleted: true),
      ], _today);
      expect(snapshot['version'], 1);
      expect(snapshot['tasks'], [
        {'title': 'Overdue', 'dueDate': '2026-11-10'},
        {'title': 'All day', 'dueDate': '2026-11-12'},
        {'title': 'Timed', 'dueDate': '2026-11-12', 'dueTimeMinutes': 540},
        {'title': 'Later', 'dueDate': '2026-11-15'},
      ]);
    });

    test('keeps at most limit tasks', () {
      final snapshot = buildAssistantSnapshot(
        [for (var i = 0; i < 5; i++) task('T$i', due: _today)],
        _today,
        limit: 3,
      );
      expect(snapshot['tasks'], hasLength(3));
    });
  });

  group('taskFromSharedText', () {
    test('first line is the title, the rest the notes', () {
      final t = taskFromSharedText(
        '\n  Buy milk  \r\nTwo litres\nSemi-skimmed\n',
      );
      expect(t?.title, 'Buy milk');
      expect(t?.notes, 'Two litres\nSemi-skimmed');
    });

    test('a single line has no notes', () {
      expect(taskFromSharedText('https://example.com/article')?.notes, '');
    });

    test('nothing to add', () {
      expect(taskFromSharedText(null), isNull);
      expect(taskFromSharedText('  \n \n'), isNull);
    });

    test('a long first line is shortened and kept whole in the notes', () {
      final long = 'word ' * 60;
      final t = taskFromSharedText(long)!;
      expect(t.title.length, lessThanOrEqualTo(maxSharedTitleLength));
      expect(t.title, endsWith('…'));
      expect(t.notes, long.trim());
    });
  });
}
