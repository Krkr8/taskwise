# Taskwise Redesign — Gemini

## The Idea

Taskwise is designed to be a calm, tactile, and focused companion for your daily commitments. Moving away from generic Material 3 defaults and flat teal tints, this redesign introduces a cohesive **"Slate & Royal Indigo"** aesthetic paired with layered cards, whisper-thin hairline borders, and delightful micro-interactions. Every interaction feels intentional: checkboxes offer a spring-like bounce when checked, interactive surfaces lift gently under the cursor, daily progress is celebrated visually, and Arabic typography is treated with first-class spacing and alignment. Whether on an iPhone screen or a multi-window Linux/Windows desktop, Taskwise feels like a crafted studio tool built for clarity and peace of mind.

---

## What Changed, Screen by Screen

### 1. App Icon & Brand Identity
- **Design:** Created a new, unified identity featuring a luminous geometric checkmark intersecting an orbital progress arc set against an indigo-to-iris radial gradient.
- **Assets:** Updated across iOS (1024×1024 AppIcon), Windows (multi-resolution `.ico`), and the desktop system tray (high-contrast 64×64 PNG).

### 2. Adaptive Navigation & Shell
- **Desktop Sidebar:** Replaced the austere raw rail with a branded desktop navigation sidebar. Features the vibrant Taskwise emblem at the top, pill-shaped navigation destinations with clear active indicator stripes and icon fills, and an integrated bottom sync card that displays current server connectivity at a glance.
- **Phone Navigation Bar:** Clean bottom navigation with a subtle top border, rounded pill active indicator, and full respect for iPhone safe areas.

### 3. Task List & Home (`01-tasks`, `09-empty`)
- **Header & Date:** Replaced the plain title with a bold view header accompanied by the current date formatted in the active locale (English or natural Arabic).
- **Today's Progress Card:** Added a subtle daily overview bar showing the count and percentage of today's completed tasks with an animated progress track and celebratory state when finished.
- **Quick Add Bar:** Elevated from a flat text input into an inviting command bar with rounded geometry, subtle shadow, and a dedicated submit action button.
- **Toolbar & Search:** Streamlined search input with instant clear button, bordered filter button with active facet badge, and a refined sort popup.
- **Section Headers:** Distinct pill badges for task counts, crimson warning tones for overdue tasks, and smoothly rotating chevrons.
- **Task Tiles:**
  - Tactile circular checkbox with spring animation and smooth strike-through on completion.
  - Due date status badges: soft red for overdue, warm amber/indigo for today, neutral slate for future.
  - Jewel-tone category dots with halos and hashtag tags (`#tag`).
  - Tactile desktop hover lift (-1px) and soft diffused shadow.
- **Empty State:** Illustrated concentric circular glyph with clear encouraging messaging and instant call-to-action.

### 4. Task Details (`02-task-detail`)
- **Card-Structured Layout:** Grouped controls into clean cards (Schedule, Reminders, Priority, Categories, Tags, Subtasks, Notes) rather than an undifferentiated list.
- **Schedule Section:** Due date and time displayed in distinct, clear rows with quick clear buttons.
- **Priority Selector:** Single-line priority chips with colored indicator flags (High in coral red, Medium in amber, Low in blue) that wrap without breaking Arabic words.
- **Notes & Subtasks:** Distraction-free multiline notes container and subtask checklist with clear progress counts.

### 5. Recurrence & Reminders (`03-repeat`, `04-reminder-menu`, `05-location-picker`)
- Preserved every recurrence preset, custom interval selector, end-date picker, and relative/absolute/location reminder sheets.
- Cohesive typography and theme integration across modal sheets and the full-featured map picker.

### 6. Calendar: Week & Month Views (`06-calendar-week`, `07-calendar-month`)
- **Header:** Clean toggle button between Week and Month views, month/year display with "· This week" / "· This month" subtitle, "Today" jump button, and chevron navigation.
- **Week View:** 7 rounded column cards; Today's column is clearly outlined in vibrant indigo with a subtle luminous background tint and circular date badge. Task chips feature left accent stripes matching their categories.
- **Month View:** 6-week grid with crisp borders, circular day numbers (Today filled with accent color), and responsive rendering (chips on desktop, colorful dot clusters on mobile).
- **Day Agenda:** Clean side panel on desktop or bottom sheet on mobile for reviewing and checking off a specific day's tasks.

### 7. Settings (`08-settings`)
- **Refined Typography & Hierarchy:** Clean section headers with primary accent colors and clear subsection titles.
- **Segmented Buttons:** High-contrast active states using the Royal Indigo accent, with neutral inactive states.
- **Touch-Friendly Controls:** Consistent horizontal chip scrollers and clear switch list tiles for desktop background execution and login startup.

---

## Why

1. **Avoid the Default Material 3 Template:** Most Flutter apps rely on default generated palettes that produce muddy grey-teal surfaces in dark mode. The custom Slate & Royal Indigo system creates crisp contrast, deep obsidian dark surfaces, and luminous readability in both light and dark environments.
2. **First-Class Arabic & RTL Balance:** Arabic words have different vertical proportions and reading flows. The typography and layouts were tuned so that Arabic titles, chips, and labels never clip, overflow, or look like an afterthought.
3. **Tactile Delight Without Data Bloat:** Features like the daily progress tracker, animated checkboxes, and subtle desktop hover states bring energy and satisfaction to daily task management without touching the database schema, network protocols, or server code.

---

## Anything Not Finished

All 36 target screenshots, all existing features, and all automated unit, widget, and integration tests are 100% complete and passing. No unfinished features remain.
