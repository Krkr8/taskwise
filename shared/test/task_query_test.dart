import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _today = LocalDate(2026, 10, 20);

TaskEntry _entry(
  String id, {
  String title = 'Task',
  String notes = '',
  LocalDate? due,
  int? time,
  Priority priority = Priority.none,
  String? categoryId,
  Set<String> tags = const {},
  bool done = false,
  DateTime? completedAt,
  int createdMinute = 0,
  bool deleted = false,
}) => TaskEntry(
  task: Task(
    id: id,
    title: title,
    notes: notes,
    dueDate: due,
    dueTimeMinutes: time,
    priority: priority,
    categoryId: categoryId,
    done: done,
    completedAt: completedAt,
    createdAt: DateTime.utc(2026, 10, 1, 0, createdMinute),
    updatedAt: DateTime.utc(2026, 10, 1),
    deleted: deleted,
  ),
  tagIds: tags,
);

List<String> _ids(Iterable<TaskEntry> entries) => [
  for (final e in entries) e.task.id,
];

void main() {
  group('TaskFilter', () {
    final entries = [
      _entry('a', title: 'Buy milk', categoryId: 'home', tags: {'errand'}),
      _entry(
        'b',
        title: 'Report',
        notes: 'Send to MILK team',
        categoryId: 'work',
      ),
      _entry('c', title: 'Gym', priority: Priority.high, tags: {'health'}),
      _entry('d', title: 'اشتري خبز', priority: Priority.low),
    ];

    List<String> run(TaskFilter f) => _ids(entries.where(f.matches));

    test('empty filter matches everything', () {
      expect(const TaskFilter().isEmpty, isTrue);
      expect(run(const TaskFilter()), ['a', 'b', 'c', 'd']);
    });

    test('text search is case-insensitive over title and notes', () {
      expect(run(const TaskFilter(text: ' milk ')), ['a', 'b']);
      expect(run(const TaskFilter(text: 'خبز')), ['d']);
    });

    test('values in one facet are ORed, facets are ANDed', () {
      expect(run(const TaskFilter(categoryIds: {'home', 'work'})), ['a', 'b']);
      expect(run(const TaskFilter(priorities: {Priority.high, Priority.low})), [
        'c',
        'd',
      ]);
      expect(
        run(const TaskFilter(categoryIds: {'home'}, tagIds: {'health'})),
        isEmpty,
      );
      expect(run(const TaskFilter(text: 'gym', tagIds: {'health', 'errand'})), [
        'c',
      ]);
    });

    test('activeFacetCount ignores text', () {
      expect(
        const TaskFilter(
          text: 'x',
          categoryIds: {'a'},
          tagIds: {'b'},
        ).activeFacetCount,
        2,
      );
    });
  });

  group('sorting', () {
    final entries = [
      _entry('undated-high', priority: Priority.high, createdMinute: 1),
      _entry(
        'oct21-9am',
        due: LocalDate(2026, 10, 21),
        time: 540,
        createdMinute: 2,
      ),
      _entry('oct21-allday', due: LocalDate(2026, 10, 21), createdMinute: 3),
      _entry(
        'oct20-low',
        due: _today,
        priority: Priority.low,
        createdMinute: 4,
      ),
      _entry('undated-none', createdMinute: 5),
    ];

    List<String> sorted(TaskSort sort) =>
        _ids([...entries]..sort((a, b) => compareEntries(a, b, sort)));

    test('by due date: date, then all-day before timed, undated last', () {
      expect(sorted(TaskSort.dueDate), [
        'oct20-low',
        'oct21-allday',
        'oct21-9am',
        'undated-high',
        'undated-none',
      ]);
    });

    test('by priority, then due date', () {
      expect(sorted(TaskSort.priority), [
        'undated-high',
        'oct20-low',
        'oct21-allday',
        'oct21-9am',
        'undated-none',
      ]);
    });

    test('by created: newest first', () {
      expect(sorted(TaskSort.created), [
        'undated-none',
        'oct20-low',
        'oct21-allday',
        'oct21-9am',
        'undated-high',
      ]);
    });

    test('by title, case-insensitive', () {
      final named = [
        _entry('1', title: 'banana'),
        _entry('2', title: 'Apple'),
        _entry('3', title: 'cherry'),
      ]..sort((a, b) => compareEntries(a, b, TaskSort.title));
      expect(_ids(named), ['2', '1', '3']);
    });
  });

  group('buildTaskSections', () {
    test('groups in display order, drops empty sections and deleted tasks', () {
      final sections = buildTaskSections(
        [
          _entry('later', due: LocalDate(2026, 11, 30)),
          _entry('today', due: _today),
          _entry('gone', due: _today, deleted: true),
          _entry('overdue', due: LocalDate(2026, 10, 1)),
          _entry('nodate'),
        ],
        today: _today,
        weekStart: WeekStart.sunday,
      );
      expect(
        [for (final s in sections) s.group],
        [TaskGroup.overdue, TaskGroup.today, TaskGroup.later, TaskGroup.noDate],
      );
      expect(_ids(sections[1].entries), ['today']);
    });

    test('applies the filter', () {
      final sections = buildTaskSections(
        [_entry('a', title: 'Milk'), _entry('b', title: 'Bread')],
        today: _today,
        weekStart: WeekStart.sunday,
        filter: const TaskFilter(text: 'bread'),
      );
      expect(sections.single.entries.single.task.id, 'b');
    });

    test('Completed is ordered by completion time, newest first', () {
      final sections = buildTaskSections(
        [
          _entry('first', done: true, completedAt: DateTime.utc(2026, 10, 18)),
          _entry('last', done: true, completedAt: DateTime.utc(2026, 10, 20)),
          _entry('middle', done: true, completedAt: DateTime.utc(2026, 10, 19)),
        ],
        today: _today,
        weekStart: WeekStart.sunday,
        sort: TaskSort.title,
      );
      expect(sections.single.group, TaskGroup.completed);
      expect(_ids(sections.single.entries), ['last', 'middle', 'first']);
    });
  });
}
