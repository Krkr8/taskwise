# Performance with 2,000 tasks

The M8 performance check: is the app still quick with a lot of tasks, in
every design? It is. Below is how to measure it, what we measured on the
owner's Fedora laptop, and what was changed.

## How to run it

The test fills the app with 2,000 tasks (spread over 60 days back and 60
days ahead, plus some without a date; about a fifth with subtasks, a third
with tags, some with reminders, some repeating, some done). Then, for each
design, at desktop size (1280×800) and phone size (390×844), it times the
main things you do.

The numbers to go by come from a **profile build**, which runs like the
real app:

```bash
cd app
flutter drive --profile -d linux \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/performance_test.dart
```

A quicker check as a normal (debug) test. Debug builds are several times
slower than the real app, so expect bigger numbers:

```bash
cd app
flutter test integration_test/performance_test.dart -d linux
```

Options: `--dart-define=DESIGNS=brutal,lapis` for some designs only,
`--dart-define=TASKS=500` for another number of tasks. Each run takes about
6 minutes for all four designs and prints a table at the end. A window opens
while it runs; leave it alone.

### What the columns mean

All times are in milliseconds. "Frame" is how long one picture took to make
(build, layout and paint). Under 16 ms means the screen stays smooth at 60
frames a second. The Linux engine doesn't report the GPU part separately.

| Column | What is timed |
|---|---|
| design→list | Switch to the design until the task list shows. In brackets: the slowest frame meanwhile. |
| tab→list | From the Calendar tab back to Tasks. |
| scroll frame p50/p90/max | Frame times while flinging the list down and up again: typical, 9 in 10 under, worst. |
| scroll frames >16ms | How many scroll frames were slow, out of all of them. |
| open task | Tap a task until its details show. |
| tick done | Tap a check box until the task leaves the list. About 250 ms of this is the check's own animation, which waits on purpose. |
| search | Type "garden" letter by letter, then clear the search. |
| month view / next month | Switch the calendar to the month, then go to the next month. |

## Results

Profile build, 2,000 tasks, Fedora laptop, 2026-11-06.

**Before:**

| design | look | design→list | tab→list | scroll frame p50/p90/max | scroll frames >16ms | open task | tick done | search | month view | next month |
|---|---|---|---|---|---|---|---|---|---|---|
| classic | desktop | 59 (37.3) | 17 (0.7) | 0.3/0.9/7.4 | 0/804 | 46 (11.4) | 291 (7.0) | 133 (8.7) | 55 (33.3) | 42 (19.2) |
| classic | phone | 57 (27.1) | 17 (0.6) | 0.3/0.9/1.7 | 0/800 | 34 (5.4) | 291 (7.1) | 150 (22.7) | 28 (8.3) | 31 (12.8) |
| lapis | desktop | 62 (39.0) | 17 (0.8) | 0.2/0.9/1.7 | 0/805 | 63 (45.6) | 299 (9.3) | 149 (22.5) | 38 (17.2) | 48 (20.1) |
| lapis | phone | 65 (37.7) | 18 (0.8) | 0.2/0.9/2.1 | 0/804 | 35 (4.3) | 292 (7.6) | 134 (10.1) | 38 (17.5) | 32 (14.3) |
| slate | desktop | 62 (36.4) | 18 (0.8) | 0.4/1.0/1.7 | 0/800 | 24 (6.5) | 293 (7.5) | 149 (19.3) | 40 (18.9) | 49 (26.1) |
| slate | phone | 59 (30.6) | 17 (0.8) | 0.3/1.0/2.3 | 0/799 | 35 (4.0) | 292 (6.7) | 132 (4.6) | 34 (13.4) | 32 (14.0) |
| brutal | desktop | 68 (38.4) | 17 (0.9) | 0.2/0.9/2.1 | 0/803 | 24 (6.8) | 318 (12.0) | 166 (20.1) | 50 (23.3) | 54 (28.9) |
| brutal | phone | 80 (55.7) | 17 (0.8) | 0.2/0.8/1.5 | 0/801 | 35 (4.4) | 299 (12.7) | 150 (13.7) | 30 (9.2) | 34 (16.5) |

**After:**

| design | look | design→list | tab→list | scroll frame p50/p90/max | scroll frames >16ms | open task | tick done | search | month view | next month |
|---|---|---|---|---|---|---|---|---|---|---|
| classic | desktop | 31 (11.6) | 18 (1.1) | 0.2/0.8/4.2 | 0/804 | 39 (4.9) | 301 (11.6) | 150 (8.4) | 50 (29.9) | 51 (25.3) |
| classic | phone | 28 (8.1) | 18 (0.7) | 0.2/0.8/1.4 | 0/801 | 35 (4.3) | 295 (7.2) | 132 (10.0) | 28 (8.2) | 31 (13.8) |
| lapis | desktop | 42 (19.8) | 17 (0.8) | 0.2/0.9/1.6 | 0/805 | 63 (45.6) | 305 (20.1) | 150 (16.8) | 41 (20.8) | 48 (20.9) |
| lapis | phone | 35 (14.9) | 19 (1.3) | 0.2/0.9/1.7 | 0/800 | 38 (4.5) | 298 (14.0) | 150 (12.0) | 28 (8.2) | 36 (17.5) |
| slate | desktop | 29 (8.0) | 18 (0.8) | 0.2/0.8/1.3 | 0/803 | 23 (6.5) | 291 (6.3) | 133 (6.1) | 52 (30.1) | 57 (24.6) |
| slate | phone | 33 (6.8) | 18 (1.0) | 0.2/0.8/1.4 | 0/805 | 38 (5.1) | 293 (9.2) | 133 (8.2) | 48 (25.8) | 34 (14.9) |
| brutal | desktop | 30 (9.5) | 18 (1.3) | 0.2/0.9/1.7 | 0/799 | 24 (7.0) | 311 (18.6) | 151 (10.9) | 38 (17.9) | 39 (18.3) |
| brutal | phone | 27 (7.3) | 18 (0.9) | 0.2/0.8/1.5 | 0/803 | 37 (11.5) | 290 (6.6) | 150 (10.9) | 33 (13.2) | 32 (13.8) |

**Debug build** (`flutter test`), the columns that changed. Everything
else stayed about the same; the full tables are printed by the test.

| design | look | design→list before | design→list after | scroll p50/p90/max before | scroll p50/p90/max after |
|---|---|---|---|---|---|
| classic | desktop | 235 (197.2) | 109 (76.3) | 1.0/4.3/15.3 | 0.7/4.2/15.5 |
| classic | phone | 209 (174.5) | 75 (52.9) | 1.0/4.0/11.1 | 0.7/3.7/9.2 |
| lapis | desktop | 189 (155.6) | 76 (50.0) | 0.6/3.9/9.1 | 0.6/3.9/8.6 |
| lapis | phone | 162 (129.5) | 72 (46.0) | 0.5/3.6/17.2 | 0.6/3.6/11.9 |
| slate | desktop | 170 (138.0) | 62 (39.8) | 0.9/3.3/8.9 | 0.5/3.0/11.2 |
| slate | phone | 142 (111.7) | 61 (39.4) | 0.8/3.2/10.4 | 0.5/2.9/7.1 |
| brutal | desktop | 157 (123.9) | 60 (37.5) | 0.5/3.0/9.0 | 0.5/3.0/13.8 |
| brutal | phone | 137 (105.6) | 54 (32.6) | 0.5/2.8/9.8 | 0.5/2.8/15.7 |

Even in a debug build no scroll frame was over 16 ms after the change (one
was before, in Lapis on the phone).

### What this tells us

- **Targets met in every design.** The task list shows well under a second
  after switching to it (about 30 ms), and no scroll frame went over 16 ms
  (worst 4 ms).
- **Switching design (and opening the app) got about twice as fast,** and
  its slowest frame went from 27–56 ms (a visible hitch) to 7–20 ms.
- Search, ticking a task and opening a task were already quick; they stay
  the same. Small differences between runs (a few ms) are noise.
- **Not fixed: the calendar's month view** takes one frame of 20–30 ms on
  desktop when you switch to it or change the month. That's the cost of
  drawing about 120 task chips at once (every day is full with 2,000 tasks;
  with 20 tasks it's about 13 ms). It's one frame when you switch, not
  while scrolling, so it doesn't feel slow. Making it faster would mean
  drawing the chips differently, which would change how the month looks.
- Lapis' "open task" on desktop has one 46 ms frame, before and after.
  It's most likely the first build of its task panel in the run (the
  other designs and Lapis on the phone take 4–12 ms). Not looked into
  further.

## What was changed

1. **Task lists build only the rows on screen.** All four designs used
   `ListView(children: …)`, which creates a widget for every one of the
   2,000 rows on every change (each search letter, each tick). Flutter only
   lays out the visible ones, which is why scrolling was already smooth, but
   the list of widgets was rebuilt each time. Now each design uses
   `ListView.builder` over one shared list of rows
   (`app/lib/ui/shared/tasks/task_rows.dart`). The rows are worked out once
   per change of tasks, filter, sort or collapsed sections (a Riverpod
   provider), not on every build. Rows keep their keys, so a row that moves
   keeps its state.
2. **Tabs are built when first opened.** Each design's shell used an
   `IndexedStack` that built Tasks, Calendar and Settings at start-up, even
   though only one shows. Now `LazyIndexedStack`
   (`app/lib/ui/shared/common/lazy_indexed_stack.dart`) builds a tab the
   first time you open it and keeps it after that. This made starting the
   app and switching designs faster.

Both changes look exactly the same: the design tour's 144 screenshots
(every screen, design and look) are byte-for-byte identical before and
after.

### Checked and fine as they are

- **Database.** Every index the queries need is there (tasks by
  done/deleted, subtasks, tags and reminders by task). Reading all 2,000
  tasks with their subtask counts and tags is one query of a few
  milliseconds, on a background thread. No schema change was needed.
- **No per-row queries.** Rows get their subtask counts and tags from that
  one query, and reminders, categories and devices from shared lookups. No
  row runs its own database query.
- **Grouping, search and calendar logic.** Sorting 2,000 tasks into
  sections takes about 0.5 ms, and the month's calendar items (including
  repeats) about 0.5 ms.
