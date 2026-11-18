# M13: Unfolding subtasks, Skip, missed repeats (design)

Asked for by the maintainer on 2026-11-18, with a sketch of a task whose subtasks hang
under it on a tree line.

## 1. Subtasks unfold under the task
- **Why:** see and tick a task's checklist without opening its details.
- Subtasks hang under the task row on a tree line (vertical line down the left, a short
  branch to each subtask). Each subtask is a smaller, indented row with its own checkbox,
  tickable in place. Folded rows keep today's "2/5" chip.
- Works in the main list and in the calendar's day lists (month day agenda, week columns).
- **New per-device setting** (Settings → Tasks, "Tapping a task with subtasks"):
  1. *Open details and show subtasks* (default): tap opens the details (side panel /
     full screen on phone) and unfolds the subtasks in the list.
  2. *Show subtasks only*: tap folds/unfolds; a small arrow on the row opens the details.
  3. *Open details only*: today's behaviour.
  Tasks without subtasks always open their details on tap.
- Unfolded state is kept in memory (not across restarts).

## 2. Skip (any task)
- **Why:** mark a task as "not needed" without pretending it was done.
- A Skip action in the task details. A skipped task is stored as `done = true` plus a new
  `skipped = true` field, so everything that treats done tasks as finished (grouping,
  reminders, Siri's "what's due") keeps working, and devices still on 1.1.0 see it as done.
- Completed shows it with a distinct "Skipped" look. Undo bar as for completing.
- Repeating task: the next occurrence appears, exactly as when it's ticked.
- Un-ticking a skipped task from Completed reopens it (clears both flags).
- Approaches considered: a `skipped` flag on top of done (chosen), or a 3-state status
  replacing `done` (cleaner model, but touches every `done` check and breaks old devices).

## 3. Missed repeats
- **Why:** a repeating task that wasn't done shouldn't block the next one.
- On app start, resume and at midnight: for each open repeating task whose next occurrence
  after its due date is today or earlier, create a copy on the first occurrence that is
  today or later (the same date ticking it would give, `_spawnNext`). A daily task's copy
  lands on today; a weekly Monday task found on a Wednesday gets next Monday. The old task
  stays in Overdue without the rule; the copy takes the rule, content, tags, reminders,
  device targets and subtasks (unticked).
- Only one overdue copy stays (maintainer's choice): days in between aren't created.
- The copy's id is derived from the old task's id and the new date (UUID v5-style), so two
  devices doing the rollover before syncing create the same task (last-write-wins merges).
- Approaches considered: saved copies (chosen), or virtual occurrences computed on the fly
  (rejected: reminders, sync and the calendar all work on saved tasks).

## Per-design look
Mockups from four design agents in `design/m13/<design>.html`; the maintainer picks or
adjusts each before building.

## Left to the builder
Exact widget split (shared tree-line/subtask rows in `ui/shared/tasks/` with per-design
styling), schema migration for `skipped` and the setting, tests for the rollover logic in
`shared`.
