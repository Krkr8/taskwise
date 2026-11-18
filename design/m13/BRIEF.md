# M13 design brief (one design per agent)

Taskwise is a Flutter task app (repo root = current directory) with four complete
designs, each in `app/lib/ui/designs/<name>/` (theme/, tasks/, calendar/, settings/).
Screenshots of every design are in `design/<name>/` (phone-light, phone-arabic,
desktop-light, desktop-dark). You design ONE design's version of three new features.
**Do not edit any app code.** Your only output is `design/m13/<name>.html`.

## Features to design
1. **Subtasks unfold under the task.** Today a task row shows a "2/5" subtask chip and
   tapping opens the details (side panel on wide screens, full screen on phone).
   New: subtasks hang under the task row on a tree line (a vertical line from the
   task down the left side, with a short horizontal branch to each subtask, which
   is a smaller indented row/box with its own checkbox, tickable in place).
   Works in the main list (groups: Overdue, Today, Tomorrow, This week, Later,
   No date, Completed) AND in the calendar's day list (month view's day agenda,
   week view's day columns). A per-device setting picks what a tap does:
   "Open details and show subtasks" (default), "Show subtasks only" (then a small
   arrow/button on the row opens the details), "Open details only" (today's behaviour).
   Show: folded vs unfolded state, the arrow for "subtasks only" mode, done subtasks.
2. **Skip.** Any task can be skipped from the task details (pick where the Skip action
   lives in this design's details panel; next to/near Done or in its menu). A skipped
   task leaves the list and appears in Completed with a distinct "Skipped" look (not
   the same as done: e.g. a Skipped label/icon, different strike or muted colour).
   For a repeating task, skipping makes the next occurrence appear. An Undo bar
   appears after skipping ("Skipped 'title'  Undo"), like completing has.
3. **Missed repeats.** When a repeating task wasn't done and its next date arrives, the
   old one stays in Overdue and a new copy appears in Today. No new UI is needed,
   but show it in the list mockup (same title in Overdue and Today).
4. **Settings row** for the tap choice (in this design's Settings style, Tasks area).

## Deliverable
A single self-contained HTML file (inline CSS, no external scripts; Google Fonts OK)
that is a faithful mockup of THIS design: read its theme tokens (`theme/tokens.dart`,
`theme/app_theme.dart` or similar), `tasks/task_tile.dart`, `tasks/task_detail.dart`,
`tasks/task_list_page.dart`, `calendar/*`, `settings/settings_page.dart`, and look at
the screenshots, so colours, type, radii, borders, spacing and icons match exactly.
Include, each labelled:
- Phone, light: task list with Overdue + Today, one task unfolded (3 subtasks, 1 done),
  one folded with "2/5", the missed-repeat pair, and the Undo bar after a skip.
- Phone, light: the "Show subtasks only" mode row with its details arrow.
- Desktop, dark: list + details side panel showing the Skip action.
- Completed group with one done and one skipped task.
- Calendar month day agenda (or week column) with an unfolded task.
- The Settings row.
- Below the mockups, a short "Build notes" list (max 15 lines): which Dart files and
  widgets change, the exact colours/tokens used for the tree line, skipped look,
  and Skip button, and any choice you made.
Keep it in the design's spirit; don't invent a new visual style. Be concise.
When done, reply with just the file path and 3 lines on your key choices.
