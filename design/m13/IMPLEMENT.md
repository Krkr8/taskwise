# M13 design task: build the new features into ONE design

Taskwise is a Flutter task app (repo: `app/` Flutter, `shared/` pure Dart). It has four
designs, each with its own screens in `app/lib/ui/designs/<design>/`. Read
`docs/architecture.md` ("Designs" and "How to change a screen") first. You build the M13
features into the ONE design named in your task, and touch nothing in other design folders.

## What's already built (use it, don't change it)

The data side and the shared pieces are done and tested (commit "WIP M13" on your branch):

- `Task.skipped` (`shared/lib/src/models/task.dart`): a skipped task has `done == true`
  and `skipped == true`. Un-ticking clears both.
- `app/lib/ui/shared/tasks/task_actions.dart`:
  - `Future<void> skipTask(BuildContext context, WidgetRef ref, Task task)` — skips with
    an Undo snackbar (texts already done).
  - `void handleTaskTap(WidgetRef ref, {required String taskId, required bool hasSubtasks, required VoidCallback openDetails})`
    — what a tap on a task row does, following the setting.
  - `bool showsDetailsArrow(WidgetRef ref, {required bool hasSubtasks})` — true when the
    row must show its own "open details" arrow (setting = subtasks only).
- `app/lib/state/providers.dart`: `expandedTasksProvider` (`Set<String>` of unfolded task
  ids; `.notifier.toggle/expand/collapse`), `subtaskCountsProvider` (`Map<String,int>`,
  task id → subtask count, only tasks that have subtasks; use it in the calendar, where
  you only have `Task`s), `subtasksProvider(taskId)`.
- `app/lib/ui/shared/tasks/subtask_tree.dart`: `SubtaskTree(taskId:, style:)` draws the
  subtasks under a task on a tree line (vertical line + branch per subtask, RTL-aware),
  each tickable in place. `SubtaskTreeStyle` sets line colour/width, `lineInset` (start
  edge → line, usually the parent checkbox centre), `indent` (start edge → subtask rows),
  text styles, a `checkbox` builder, an optional `rowDecoration(done)`, paddings/gaps and
  `branchRadius`. Read the file for all fields.
- Settings: `AppSettings.taskTapAction` (`TaskTapAction.detailsAndSubtasks` default,
  `.subtasksOnly`, `.detailsOnly`) in `app/lib/data/app_settings.dart`;
  `settingsRepositoryProvider` → `setTaskTapAction(value)`.
- Texts (`context.l10n`, from `app/lib/ui/shared/tasks/labels.dart`): `skip`,
  `skippedLabel` ("Skipped"), `openDetails`, `showSubtasks`, `hideSubtasks`,
  `settingsTasks`, `taskTapAction`, `taskTapDetailsAndSubtasks`, `taskTapSubtasksOnly`,
  `taskTapDetailsOnly`. If you truly need another text, add it to BOTH
  `app/lib/l10n/app_en.arb` and `app_ar.arb` and run `flutter gen-l10n` in `app/`.

## The look

Your design's approved mockup is `design/m13/<design>.html` (open it and read it, including
the "Build notes" at the bottom). Match it closely, using the design's existing theme
tokens/colours (`app/lib/ui/designs/<design>/theme/`). The maintainer approved the mockups
as they are.

## What to build (all in `app/lib/ui/designs/<design>/`)

1. `tasks/subtask_tree_style.dart` (new): `SubtaskTreeStyle <design>SubtaskTreeStyle(BuildContext context)`
   (e.g. `brutalSubtaskTreeStyle`), light and dark from the theme, per the mockup.
2. `tasks/task_tile.dart`: a tap goes through `handleTaskTap` (`hasSubtasks: entry.subtaskCount > 0`,
   `openDetails:` the existing open callback). When `showsDetailsArrow` is true, the row has
   a small arrow/button (tooltip `l10n.openDetails`) that opens the details. When the task id
   is in `expandedTasksProvider`, the `SubtaskTree` hangs under the row (inside the same
   row/card, so the list's card slicing stays right); the folded row keeps its "2/5" chip.
   Done tasks in Completed: a skipped task (`task.skipped`) gets the mockup's distinct
   skipped look (marker/badge with `l10n.skippedLabel`, strike style, colours), different
   from a done one.
3. `tasks/task_list_page.dart`: only if needed for the above (e.g. how `onOpen` is passed).
4. `tasks/task_detail.dart`: a Skip action beside Done, per the mockup, shown only while
   the task is open (not done); it calls `skipTask(context, ref, task)`. If the details is a
   full-screen page on phones, pop it after skipping the same way Done/Delete behave there
   (look at how Delete is handled).
5. Calendar: the month view's day agenda (`DayAgenda` in `calendar/calendar_page.dart`) and
   the week view's day columns (`calendar/week_view.dart`, chips in
   `calendar/calendar_widgets.dart`): a real (not `projected`) task with subtasks
   (`subtaskCountsProvider`) uses `handleTaskTap` and shows a `SubtaskTree` under it when
   unfolded (compact in narrow week columns). Projected repeats never unfold and tap as
   today. Done skipped tasks get the skipped look where done tasks are shown.
   If your design has no own copy of a calendar file, it uses Classic's; then leave it.
6. `settings/settings_page.dart`: a new "Tasks" section (`l10n.settingsTasks`, placed after
   Date & time) with the "Tapping a task with subtasks" (`l10n.taskTapAction`) choice of the
   three values, in this design's own control style, saving with `setTaskTapAction`.

Keep the design's code style (look at neighbouring code). No new packages.
Never log task titles or notes.

## Tests (write first, see them fail, then build)

In this design's widget test file — Classic: `app/test/widget/app_test.dart` (use its
`appTest` helper); Brutal/Lapis/Slate: `app/test/widget/designs/<design>_app_test.dart`.
Add a group `M13` with:
- a task with 3 subtasks, desktop size: tap the task → the 3 subtask titles are visible
  and the details are open; tap it again → the subtask titles are gone.
- `taskTapAction: TaskTapAction.subtasksOnly` (pass it in the settings/ store it with the
  settings repository like the test file does for other settings): tap → subtasks
  visible, details NOT open; tapping the `openDetails` arrow opens the details.
- a task without subtasks: tap → details open, no tree.
- details → Skip: the task leaves Today and shows in Completed (expand the Completed
  section) with the "Skipped" label; Undo in the snackbar brings it back.
- Settings shows the `taskTapAction` row with its three choices; picking "Show subtasks
  only" stores `TaskTapAction.subtasksOnly`.
- calendar month view: a day with a task that has subtasks; open the day's agenda and tap
  the task → its subtasks show. A projected (future repeat) item never shows a tree.

Read the file's existing tests first to see how they open screens, read the DB inside
`tester.runAsync`, and unmount at the end (drift streams and the fake clock).

## Commands (from `app/`)

- First, in your checkout: `flutter pub get` (from the repo root is fine too).
- Take ccache off PATH before flutter: `export PATH=$(echo $PATH | tr ':' '\n' | grep -v ccache | paste -sd:)`
- Run ONLY your design's test file: `flutter test test/widget/designs/<design>_app_test.dart`
  (Classic: `flutter test test/widget/app_test.dart`). If it fails with "Unable to connect
  to flutter_tester process", re-run it. Then `flutter test test/widget/subtask_tree_test.dart`.
- `flutter analyze` must report no issues; `dart format` your files.
- Do NOT run the design tour, integration tests or a Linux/Android build (the machine has
  16 GB RAM and four of these tasks run at once). The controller runs them afterwards.

## Finish

Commit your work on your branch in one commit `M13 <design>: subtasks tree, Skip, tap setting`
with author `Krkr8 <189832548+Krkr8@users.noreply.github.com>` and the line
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` at the end of the message.
Do not push. Do not edit files outside `app/lib/ui/designs/<design>/`, your design's test
file and (only if needed) the two ARB files + generated l10n files. Do not start subagents.

Reply with: status (DONE / DONE_WITH_CONCERNS / BLOCKED), the commit hash, the test
result line, and any concerns in at most 8 lines.
