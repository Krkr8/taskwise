# M13: Unfolding subtasks, Skip, missed repeats — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Subtasks unfold under their task on a tree line (list and calendar), any task can be skipped from its details, and an unfinished repeating task stays in Overdue while its next copy appears on its own, in all four designs. Released as 1.2.0.

**Architecture:** Data and logic changes are built once: `shared` gets `Task.skipped` and the pure "missed repeat" date rule, the app's `TaskRepository` gets skip, deterministic next-copy ids and a roll-over, and a watcher runs the roll-over. The UI is built once as shared pieces (tap behaviour, expanded-set provider, a `SubtaskTree` widget drawn from a per-design style, a `skipTask` action), and each design wires them into its own tile, details, calendar and settings, following its mockup in `design/m13/<design>.html`.

**Tech Stack:** Flutter 3.47.7, Riverpod 3, drift (schema v4 → v5), `uuid` 4.6.0 (v5 ids), `shared` pure Dart.

**Spec:** `docs/superpowers/specs/2026-11-18-m13-subtasks-skip-repeats-design.md`. Per-design looks: `design/m13/{brutal,classic,lapis,slate}.html` (approved by the maintainer as they are, including the "Build notes" at the bottom of each).

## Global Constraints

- Every screen change is made in all four designs (`app/lib/ui/designs/{classic,lapis,slate,brutal}/`); shared pieces live in `app/lib/ui/shared/` and never import from a design folder.
- New texts go in both `app/lib/l10n/app_en.arb` and `app_ar.arb` (Arabic plural/RTL rules as in existing strings).
- No new packages. `uuid` is already pinned at 4.6.0.
- Never log task titles, notes, places or tokens (`appLog`).
- Tap setting is device-only (`synced: false`); default `detailsAndSubtasks`.
- Skipped = `done: true` + `skipped: true`. Un-ticking clears both.
- Missed repeats keep only one overdue copy; the new copy goes on the first occurrence that is today or later.
- Commit as `Krkr8` (noreply). Never put the maintainer's name, email or server in commits or docs.
- Release 1.2.0: `CHANGELOG.md`, `app/pubspec.yaml` (`1.2.0+14`), `app/lib/version.dart`.

## Review Focus

1. **Two devices roll over the same task before syncing** → they must create the same copy (same task, subtask, reminder and tag-link ids), not two. Test in Task 2 with two databases.
2. **Complete → Undo → Complete again** (now that next-copy ids are deterministic) → one live copy, not an insert conflict. Test in Task 2.
3. **A device on 1.1.0 syncs a skipped task** → it reads it as done (extra JSON field ignored). `Task.fromJson` without `skipped` gives `false`. Test in Task 1.
4. **A repeating task whose series has ended** (COUNT/UNTIL reached) and is overdue → no copy, task left untouched, no endless retries. Test in Task 1 and Task 2.
5. **Projected (faded) calendar repeats and tasks without subtasks** → never unfold; tap behaves as today. Test in the design tasks (Task 4–7) via the Brutal and Classic widget tests.

---

### Task 1: Shared model and missed-repeat rule

**Files:**
- Modify: `shared/lib/src/models/task.dart` (field, `fromJson`, `toJson`, `copyWith`, `==`, `hashCode`)
- Create: `shared/lib/src/logic/missed_repeats.dart`; export it from `shared/lib/taskwise_shared.dart`
- Modify: `shared/test/fixtures/sync/records.json`, `shared/test/fixtures/sync/flow.json` (every task record gets `"skipped": false`)
- Test: `shared/test/models_test.dart`, `shared/test/missed_repeats_test.dart`

**Interfaces:**
- Produces: `Task.skipped` (`bool`, default `false`; JSON key `skipped`, missing → `false`); `copyWith({bool? skipped})`.
- Produces: `LocalDate? missedRepeatDate(Task task, LocalDate today)` — the date for the new copy, or null when no roll-over is due.

- [ ] **Step 1: Write failing tests**
  - models: `Task.fromJson` without `skipped` → `skipped == false`; round-trip keeps `skipped: true`; `toJson()` always has the `skipped` key.
  - `missedRepeatDate`, with `today = 2026-11-18`:
    - daily task due 2026-11-14, open → `2026-11-18`
    - weekly MO task due Mon 2026-11-09, today Wed 2026-11-18 → `2026-11-23` (first occurrence ≥ today)
    - weekly MO task due Mon 2026-11-16, today Wed 2026-11-18 → `null` (next occurrence 11-23 hasn't arrived)
    - daily task due today → `null`; due yesterday → `2026-11-18`
    - done task, deleted task, task without rule, task without due date → `null`
    - daily `COUNT=3` series whose last occurrence was the due date → `null`
- [ ] **Step 2:** `cd shared && dart test` → new tests fail.
- [ ] **Step 3: Implement.** `missedRepeatDate`: null unless `!done && !deleted && dueDate < today` and `RecurrenceRule.tryParse(recurrenceRule)` is non-null; let `n = rule.nextAfter(due)`; null if `n == null || n.isAfter(today)`; else return `rule.nextAfter(today.addDays(-1))`. Add `"skipped": false` to the fixtures' task records.
- [ ] **Step 4:** `cd shared && dart test` and `cd server && npm test` → all pass (the server replays the same fixtures).

### Task 2: Database, repository: skip, deterministic copies, roll-over

**Files:**
- Modify: `app/lib/data/db/tables.dart` (`Tasks.skipped`: `boolean().withDefault(const Constant(false))()`), `app/lib/data/db/app_database.dart` (`schemaVersion => 5`, `from4To5` adds the column); run `dart run drift_dev make-migrations` and `dart run build_runner build` from `app/`, fill the generated migration test in `app/test/drift/`.
- Modify: `app/lib/data/repositories/repository_base.dart`, `app/lib/data/repositories/task_repository.dart` (`toTask`, `toCompanion`, `setDone`, `_spawnNext`, new `rollOverMissedRepeats`)
- Test: `app/test/data/task_repository_test.dart`

**Interfaces:**
- Consumes: `Task.skipped`, `missedRepeatDate` (Task 1).
- Produces:
  - `String derivedId(String name)` on `RepositoryBase`: UUID v5 of `name` in a fixed Taskwise namespace (a constant UUID in that file).
  - `Future<Completion> setDone(String id, {required bool done, bool skipped = false})` — writes `skipped: done && skipped`; un-done clears it. A skipped repeating task spawns the next copy exactly like completing.
  - `Future<int> rollOverMissedRepeats(LocalDate today)` — returns how many copies it made.

- [ ] **Step 1: Write failing tests** (`task_repository_test.dart`):
  - `setDone(id, done: true, skipped: true)` → task done, skipped, `completedAt` set; repeating → next copy exists, its `skipped == false`; `undoCompletion` → open, not skipped, rule back, copy deleted.
  - `setDone(id, done: false)` on a skipped task → `skipped == false`.
  - complete repeating → `undoCompletion` → complete again → exactly one live copy with the same id as the first time.
  - `rollOverMissedRepeats(2026-11-18)` with a daily task due 11-14 that has 2 subtasks (1 ticked), a tag, a relative reminder: returns 1; old task keeps due 11-14, `recurrenceRule == null`, still open; new task due 11-18 with the rule, both subtasks unticked, same tag, one reminder. A second call returns 0.
  - Two in-memory databases with the same task (same ids) both run `rollOverMissedRepeats` → the copy's task id, subtask ids, reminder ids and tag-link ids are equal in both.
  - Overdue repeating task whose series ended → returns 0, task unchanged (rule kept).
- [ ] **Step 2:** `cd app && flutter test test/data/task_repository_test.dart` → fail.
- [ ] **Step 3: Implement.**
  - `_spawnNext(Task task, RecurrenceRule rule, {LocalDate? on})`: date is `on ?? (current rule)`. All ids derived: task `derivedId('${task.id}/${date.toIso()}')`, subtask `derivedId('$copyId/s/${s.id}')`, reminder `derivedId('$copyId/r/${r.id}')`. Write with `insertOnConflictUpdate` (so an undone, tombstoned copy comes back live). Tag links keep using `setTaskTags` (it already keeps one live link per tag).
  - `rollOverMissedRepeats`: in one transaction, for every open, non-deleted task with a rule, `missedRepeatDate(task, today)`; when non-null, clear the old task's rule (stamp `updatedAt`/`updatedByDevice`) and `_spawnNext(task, rule, on: date)`.
- [ ] **Step 4:** `flutter test test/data/ test/drift/ test/sync/` → pass.

### Task 3: Shared UI pieces, settings, watcher, texts

**Files:**
- Modify: `app/lib/data/app_settings.dart` (`enum TaskTapAction { detailsAndSubtasks, subtasksOnly, detailsOnly }`, field `taskTapAction`, default `detailsAndSubtasks`, in `copyWith`/`==`/`hashCode`), `app/lib/data/repositories/settings_repository.dart` (key `task_tap`, `setTaskTapAction`, `synced: false`)
- Create: `app/lib/state/missed_repeats.dart` — `missedRepeatsProvider`, started from `app/lib/app.dart` next to `reminderSchedulerProvider`.
- Modify: `app/lib/state/providers.dart` — `expandedTasksProvider` (`Notifier<Set<String>>`: `toggle(id)`, `expand(id)`, `collapse(id)`), `subtaskCountsProvider` (`Provider<Map<String, int>>` from `taskEntriesProvider`, only tasks with > 0).
- Modify: `app/lib/ui/shared/tasks/task_actions.dart` — `skipTask`, `handleTaskTap`.
- Create: `app/lib/ui/shared/tasks/subtask_tree.dart` — `SubtaskTree` + `SubtaskTreeStyle`.
- Modify: `app/lib/l10n/app_en.arb`, `app_ar.arb`.
- Modify: `app/lib/data/backup.dart` only if it lists task columns by hand (check; JSON goes through `Task.toJson`).
- Test: `app/test/data/category_settings_test.dart` (or a new `app/test/data/settings_test.dart`), `app/test/state/missed_repeats_test.dart`, `app/test/widget/subtask_tree_test.dart`.

**Interfaces:**
- Consumes: `setDone(..., skipped:)`, `rollOverMissedRepeats` (Task 2).
- Produces:
  - `Future<void> skipTask(BuildContext context, WidgetRef ref, Task task)` — `setDone(done: true, skipped: true)`, clears the selected task like delete does, snackbar `l10n.taskSkipped(task.title)` or, for repeats, `l10n.skippedNextOn(date)` / `l10n.doneSeriesEnded`, with Undo → `undoCompletion`. Same `undoSnackBarDuration`.
  - `void handleTaskTap(WidgetRef ref, {required String taskId, required bool hasSubtasks, required VoidCallback openDetails})`: no subtasks or `detailsOnly` → `openDetails()`; `subtasksOnly` → `toggle`; `detailsAndSubtasks` → `toggle` and `openDetails()`.
  - `bool showsDetailsArrow(WidgetRef ref, {required bool hasSubtasks})` → `hasSubtasks && action == subtasksOnly`.
  - `SubtaskTree({required String taskId, required SubtaskTreeStyle style})` watches `subtasksProvider(taskId)`; draws the vertical line from the parent's checkbox centre and a branch to each subtask (`CustomPaint`, mirrored in RTL); each subtask row has a checkbox that calls `setSubtaskDone`, done rows struck through.
  - `SubtaskTreeStyle({required Color line, double lineWidth = 2, required double indent, required double lineInset, BoxDecoration Function(bool done)? rowDecoration, required Widget Function(BuildContext, Subtask, VoidCallback onToggle) checkbox, required TextStyle text, required TextStyle doneText, EdgeInsetsGeometry rowPadding, double rowGap})`.
  - `missedRepeatsProvider`: listens to `taskEntriesProvider` and `todayProvider`; when any entry has a non-null `missedRepeatDate`, calls `rollOverMissedRepeats(today)` (debounced 1 s, one run at a time). On resume (`AppLifecycleListener`), invalidates `todayProvider` if the date changed.
  - Texts (EN; AR to match): `settingsTasks` "Tasks", `taskTapAction` "Tapping a task with subtasks", `taskTapDetailsAndSubtasks` "Open details and show subtasks", `taskTapSubtasksOnly` "Show subtasks only", `taskTapDetailsOnly` "Open details only", `skip` "Skip", `skipped` "Skipped", `taskSkipped` "Skipped “{title}”", `skippedNextOn` "Skipped. Next one {date}", `openDetails` "Open details".
- [ ] **Step 1: Write failing tests**: settings round-trip of `taskTapAction` (default `detailsAndSubtasks`, stored device-only); watcher test with a fake clock: a daily task due 2 days ago gets its copy without any UI; `SubtaskTree` widget test: shows 3 rows for 3 subtasks, tapping a checkbox ticks it in the database, RTL builds without error.
- [ ] **Step 2:** run them → fail.
- [ ] **Step 3: Implement** the interfaces above; `flutter gen-l10n` runs with the build.
- [ ] **Step 4:** `flutter test` (whole app) → pass; `flutter analyze` → clean.

### Tasks 4–7: One design each (Brutal, Classic, Lapis, Slate & Indigo)

Each design is one task with the same steps; they're independent of each other and can run in parallel. The look comes from `design/m13/<design>.html` (mockup plus its "Build notes"), which the maintainer approved as is.

**Files (per design `<d>`):**
- Create: `app/lib/ui/designs/<d>/tasks/subtask_tree_style.dart` — `SubtaskTreeStyle <d>SubtaskTreeStyle(BuildContext context)` from the mockup's colours/tokens.
- Modify: `app/lib/ui/designs/<d>/tasks/task_tile.dart` — tap via `handleTaskTap`; details arrow when `showsDetailsArrow`; `SubtaskTree` under the row when the task is in `expandedTasksProvider`; the skipped look in Completed (per mockup: badge/marker, strike style, colours).
- Modify: `app/lib/ui/designs/<d>/tasks/task_list_page.dart` — pass `openDetails` instead of the bare `onOpen` if the tile needs it; card slicing still right with a grown row.
- Modify: `app/lib/ui/designs/<d>/tasks/task_detail.dart` — Skip action beside Done (only while the task is open), calling `skipTask`.
- Modify: `app/lib/ui/designs/<d>/calendar/calendar_page.dart` (`DayAgenda`) and `.../week_view.dart` — real (non-projected) tasks with subtasks use `handleTaskTap` and show a `SubtaskTree` when expanded (`subtaskCountsProvider` tells which have subtasks); skipped look on done items.
- Modify: `app/lib/ui/designs/<d>/settings/settings_page.dart` — a "Tasks" section (`settingsTasks`) with the `taskTapAction` row in the design's own control style (Slate: `SegmentedButton`).
- Test: `app/test/widget/app_test.dart` (Classic) or `app/test/widget/designs/<d>_app_test.dart`.

**Interfaces:** Consumes everything Task 3 produces. Produces nothing for other tasks.

- [ ] **Step 1: Write failing widget tests** (for this design):
  - a task with 3 subtasks: tap → subtasks visible (by title) and details open; tap again → subtasks hidden.
  - with `taskTapAction = subtasksOnly`: tap → subtasks visible, details not open; the arrow (tooltip `openDetails`) opens details.
  - a task without subtasks: tap → details open, no tree.
  - details → Skip → task leaves Today, shows in Completed (expanded) with the `skipped` label; Undo brings it back.
  - Settings shows the `taskTapAction` row with its three choices.
- [ ] **Step 2:** run the design's test file → fail.
- [ ] **Step 3: Implement** the files above to match the mockup.
- [ ] **Step 4:** run the design's test file and `flutter analyze` → pass.
- [ ] **Step 5:** design tour for this design: `flutter test integration_test/design_tour_test.dart -d linux --dart-define=SHOTS=$PWD/../design --dart-define=DESIGNS=<d>`; compare the list and details shots with the mockup. Add an unfolded task and a skipped task to the tour's sample data if it has none.

### Task 8: Docs, release 1.2.0

**Files:** `SPEC.md` (3.1 Tasks: Skip and missed repeats; 3.2 Views: unfolding subtasks; 3.5 Settings: tap choice; M13 milestone entry; Progress Log + "Where we left off"; known issue below), `docs/architecture.md` (subtask tree + `missedRepeatsProvider`), `CHANGELOG.md` (`## [1.2.0] - <date>`), `app/pubspec.yaml` `1.2.0+14`, `app/lib/version.dart` `1.2.0`, `design/` screenshots (full tour).

- [ ] **Step 1:** full verification: `cd shared && dart test`; `cd server && npm test`; `cd app && flutter analyze && flutter test` (ccache off `PATH`); Android unit tests unaffected (no Kotlin changes; skip unless Kotlin changed); full design tour.
- [ ] **Step 2:** docs and version bump as listed. Known issue to record: a device still on 1.1.0 that edits a skipped task drops the "skipped" mark (it stays done).
- [ ] **Step 3:** commit `M13: Unfolding subtasks, Skip and missed repeats`, push to `main`.
- [ ] **Step 4:** tag `v1.2.0`, push the tag, wait for the release workflow; check that `SHA256SUMS.sig` verifies; `gh release download v1.2.0 --dir ~/Downloads/taskwise-1.2.0`.
- [ ] **Step 5:** publish the draft release (the maintainer asked for it to be ready to install; installed 1.1.0 apps only see published releases), then give the maintainer step-by-step test instructions per device.
