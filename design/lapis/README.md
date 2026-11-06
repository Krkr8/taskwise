# Lapis: a redesign of Taskwise

![App icon](app-icon.png)

## The idea

Taskwise should feel like a calm paper planner that opens on today. The colours come from lapis lazuli, the deep blue of the glazed bricks on Babylon's Ishtar Gate: ink blue on a cool, slightly grey paper, with white sheets for content. One warm colour, saffron, is kept for a single meaning: "today". You see it on today's date in the calendar, on the ring that fills up as you finish today's tasks, on the dot next to the Today section, and as the sun in the app icon. Everything else stays quiet. The font is IBM Plex Sans Arabic, which has Arabic and Latin letters drawn as one family, so a task like "Plan the weekend trip to Erbil" looks the same in the English and Arabic app.

## What changed, screen by screen

Screenshots for all four looks are in this folder (`desktop-light`, `desktop-dark`, `phone-light`, `phone-arabic`), next to the old ones in `../baseline/`.

**Everywhere**
- New colours for light and dark mode (ink blue accent, saffron for today, a deep navy dark mode instead of near-black).
- New font: IBM Plex Sans Arabic in four weights, bundled in `app/assets/fonts/` with its licence (SIL Open Font License). The Noto fonts were removed.
- Rounder, flatter controls: inputs, chips, menus, dialogs and sheets use the new colours, mostly with a thin outline instead of a grey fill.
- New app icon: a blue tile with a white check and a saffron sun. It is used for iOS, Windows (`.ico`), Linux and the tray.

**Side bar (desktop)**
- The narrow Material rail is replaced by a side bar with the Taskwise mark, the three destinations, and the number of open tasks due today or earlier next to "Tasks".
- The sync status sits at the bottom as a line of text ("Synced just now") instead of a lone icon. Clicking it opens Settings.
- Under it, two keyboard shortcuts are listed. On windows narrower than 1100 px the side bar shrinks to icons with small labels.

**Keyboard shortcuts (desktop, also with a keyboard on the iPhone)**
- Ctrl+N: jump to the quick add field, from any tab.
- Ctrl+F: jump to search.
- Ctrl+1, Ctrl+2, Ctrl+3: Tasks, Calendar, Settings.
- Esc: close the task panel.

**Tasks**
- The page now opens with the day ("Friday" over "November 6") instead of the word "Tasks".
- Next to it, a small ring shows today's progress: "5 left today, 1 done". It counts open tasks due today or overdue, plus tasks you ticked off today, and fills with saffron as you go. With nothing due it disappears. Screen readers hear "1 of 6 tasks for today done".
- Quick add comes first and looks like the main thing on the page: a white field with a blue plus. It gets a soft blue glow while you type. Search, filter and sort sit below it in a quieter row.
- Each section (Overdue, Today, Tomorrow, ...) is a white sheet with thin lines between tasks. Overdue is red and Today has a saffron dot. The collapse arrow moved to the end of the header.
- The round check now takes the priority colour and shows a faint tick when you hover over it, so you can see what a click will do. Done tasks get a filled blue circle.
- The open task gets a light blue background and a blue bar on its start edge (right side in Arabic).
- The sync invitation is a blue card. On wide windows the buttons sit on the same line as the text.
- Empty list: a small drawing of a blank planner page with the sun in the corner, "No tasks yet", and "Type one in the box above and press Enter".
- With no task open, the side panel shows the faded Taskwise mark and the hint.

**Task details**
- The title is larger and the "Title" label stays small above it.
- Date, time and repeat are grouped in one outlined block with lines between them, so "when" reads as one thing.
- Section labels (Reminders, Priority, Category, ...) are grey and smaller, so the values stand out. More room between sections.
- The detail panel is white against the paper background of the list.

**Calendar**
- The header shows the month in larger type with "This week" or "This month" below it. When you move away from the current week, that line turns into a blue "Today" link that brings you back.
- The icon that switched between week and month is now a small "Week | Month" switch, so you can see which view you are in.
- Today's column is outlined in saffron with a pale saffron fill, and today's date sits in a saffron circle (same in the month grid).
- Task chips have rounder corners and softer colours. Days outside the month are slightly greyed.
- On phones the month name is shortened ("Nov 2026") so the switch and arrows fit.

**Settings**
- Each section (Sync, Appearance, Date & time, Notifications, Location reminders, Background, Organize) sits on its own white panel with a grey heading above it.
- On desktop the column is centred in the window.
- All settings, buttons and pages are the same as before.

## Why

- **Opening on today.** Most of the time you open a task manager to see what is due now. The date header and the progress ring answer that before you scroll.
- **One meaning per colour.** Blue means "you can act on this" (buttons, selection, the plus). Saffron means "today". Red means "overdue" or "high priority". Because each colour has one job, the screen stays simple even with many tasks.
- **Sheets on paper.** White sheets on grey paper group tasks without heavy lines, and work the same in dark mode (navy sheets on darker navy).
- **One font for both scripts.** Mixed English titles in the Arabic app no longer switch between two fonts with different heights.
- **Keyboard shortcuts.** On the laptop and the Windows PC, adding a task is now Ctrl+N, type, Enter, without touching the mouse.

## Notes and things not finished

- No new packages were added.
- The location picker, sign-in, categories, places and devices pages only got the new colours, font and control shapes. Their layout is unchanged.
- In narrow week columns on the phone, long titles still break inside words ("electric / ity"). This happened before too; the columns are about 50 px wide.
- The progress ring counts tasks finished "today" using the time they were marked done on this device's clock.
- `integration_test/location_test.dart` taps "Location debug" straight after scrolling, so it is sensitive to the spacing in Settings. The spacing and the grouping of the "Saved places" and default radius rows were chosen so that it passes. If Settings changes later and that test fails with a missed tap, this is why.
- SPEC.md §3.6 still mentions Noto Sans; the app now uses IBM Plex Sans Arabic.
- Widget test changes, all for finders or texts: the new empty state text, the side bar type instead of `NavigationRail`, "Month" found by its text instead of a tooltip, an extra `ensureVisible` before tapping "Saved places", and "Synced just now" looked up inside Settings (the side bar shows it too). One new test checks Ctrl+N and Ctrl+F.
