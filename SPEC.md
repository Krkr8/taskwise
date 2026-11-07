# Taskwise — Project Specification

> Working name: **Taskwise** (rename freely). This file is the single source of truth for Claude Code.
> Work **one milestone at a time**. Do not start the next milestone until the current one is done, tested, committed, and the **Progress Log** at the bottom is updated.

---

## 0. Rules for Claude Code (read first, every session)

1. Read this whole file before doing anything. Then read the **Progress Log** to see which milestone is next.
2. Work only on the **current milestone**. If you notice something that belongs to a later milestone, write it under "Notes for later" in the Progress Log instead of doing it.
3. Start each milestone in plan mode: propose a short plan (files, packages, steps), wait for the maintainer's approval, then build.
4. Before adding any package, check it is maintained and supports the platforms it's needed on (Windows, Linux, iOS). Pin versions. Prefer fewer dependencies.
5. Verify current facts (package APIs, GitHub Actions runner names, iOS APIs, SideStore/AltStore status) from official docs instead of relying on memory.
6. Write tests for logic (data model, recurrence, sync, reminder scheduling). Run them before finishing a milestone.
7. At the end of each milestone:
   - Run `flutter analyze`, the tests, and a Linux build (`flutter run -d linux`) when relevant.
   - Commit with message `M<n>: <title>` and push.
   - Update the Progress Log: what was done, how to test it, known issues.
   - Tell the maintainer exactly what to do to test it on their devices (step by step, beginner-friendly commands).
8. Never hardcode secrets, IPs, or personal data. Config goes in settings or a config file listed in `.gitignore`.
9. The repo may become public open source later: keep code clean, documented, and licensed (MIT unless the maintainer says otherwise).
10. The maintainer develops on **Fedora (GNOME)** using Claude Code in the terminal. Commands you give must work there. Windows and iOS builds happen through GitHub Actions (and optionally on the Windows machine).

---

## 1. What we're building

A personal, self-hosted **to-do + reminders app** that runs on:

| Device | OS | Role |
|---|---|---|
| Desktop | Windows 11 | App. |
| Desktop | Linux (Fedora, GNOME on Wayland) | App. Development machine. Also an AppImage for other distributions (M9). |
| Phone | iOS 27 (iPhone) | App. **Only device that does location reminders.** |
| Cloud | Vercel (free Hobby plan) + hosted database | Sync server. Public HTTPS, reachable from anywhere. Nothing to look after. |

Single user (the maintainer). One device used at a time, so conflicts are rare. Designed so it could later be published as an open-source self-hosted app (multiple users not required now, but don't make it impossible).

### No Mac
- iOS app is built in the cloud (GitHub Actions macOS runner) as an **unsigned .ipa**, then installed with **SideStore** (or AltStore) using a free Apple ID. Free-account signing expires every 7 days and must be refreshed (SideStore can refresh on-device). A paid Apple Developer account ($99/yr) removes that limit — optional, later.
- Because of free signing: **do not use Apple Push Notifications (APNs)**. All iPhone notifications are **local notifications** scheduled by the app itself. Sync happens when the app runs (open, background refresh, geofence wake).
- Only use iOS capabilities that work with free provisioning: background location, local notifications, background fetch. Verify this in M2.
- iOS-specific Swift code cannot be compiled locally. Keep native Swift code small, isolated, and well-commented; CI is the compiler.

---

## 2. Tech stack (decided)

- **App:** Flutter (Dart), one codebase for Windows, Linux, iOS.
  - Local database: SQLite via `drift` (local-first; app works fully offline).
  - State management: Riverpod.
  - Localization: Flutter `intl` / ARB files, **English + Arabic**, full RTL support.
  - Notifications: `flutter_local_notifications` (supports Windows, Linux, iOS) — verify.
  - Maps / location picker: `flutter_map` + OpenStreetMap tiles (no API key, open-source friendly). Address search via Nominatim (respect its usage policy: user-agent, rate limit) — make the geocoding provider swappable.
  - Geofencing on iOS: a small native Swift plugin using Core Location region monitoring (or a well-maintained Flutter plugin if one fits — evaluate in M7).
- **Server (sync server):** TypeScript with **Hono**, deployed as **Vercel Functions** on the free Hobby plan. The maintainer can't maintain or secure a Linux server, so the server must be fully managed.
  - Storage: a hosted database, because Vercel has no persistent disk. Prefer **Turso** (SQLite-compatible), with **Neon** (Postgres) as the alternative. Avoid Supabase's free tier (it pauses inactive projects).
  - Public **HTTPS** on the free `*.vercel.app` address (custom domain optional). No VPN app needed on any device.
  - Scheduled jobs (tombstone purge, daily backup export) run as a **Vercel Cron** job, because serverless functions have no background process.
  - Hono is portable: the same code must also run as a plain Node server with a Dockerfile, for future open-source self-hosters.
  - The server does not reuse the Dart `shared` package. It only stores and serves records; recurrence and reminder logic stay in the app. To keep the Dart app and the TypeScript server in agreement, the sync API is defined once in `docs/sync-api.md`, with JSON fixture files in `shared/test/fixtures/` that both the Dart and the TypeScript tests load.
  - At the start of M5, verify the current free limits of Vercel Hobby (function invocations, cron frequency) and the chosen database.
- **CI/CD:** GitHub Actions: tests (Dart and TypeScript), Linux build, Windows build, unsigned iOS .ipa. Artifacts attached to GitHub Releases. Vercel deploys the server.
  - Note: macOS runners consume more minutes on private repos; public repos are free. Check current GitHub pricing and tell the maintainer.

### Repo layout
```
/app        Flutter app (windows, linux, ios)
/server     TypeScript sync server (Vercel)
/shared     Dart models and logic for the app (recurrence, grouping) + sync API fixtures
/docs       Setup guides (install, SideStore, server on Vercel, sync API)
/.github    CI workflows
SPEC.md     This file
```

---

## 3. Features

### 3.1 Tasks
Each task has:
- Title (required), notes (multi-line, plain text or simple markdown)
- Due date (optional) and due time (optional; date-only = all-day)
- Priority: none / low / medium / high (shown as color/icon)
- Category: user-defined, each with name + color. A task has 0 or 1 category. Tags optional (multiple).
- Subtasks: checklist items with their own done state, reorderable
- Done / not done; completed date
- **Repeat** (recurrence): none, daily, weekly (choose weekdays), monthly (day of month or "2nd Tuesday"), yearly, every N days/weeks/months, end: never / on date / after N times. Completing a repeating task creates/advances the next occurrence. Store as RRULE-style rule in `shared`.
  - Implemented in M3 (`shared/lib/src/logic/recurrence.dart`), stored in `Task.recurrenceRule` as e.g. `DTSTART=20261020;FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10`. `DTSTART` anchors the series (intervals and COUNT count from it); dates are floating `LocalDate`s, so DST never moves them.
  - A day that doesn't exist falls back to the month's last day: "monthly on the 31st" gives Feb 28/29, and a Feb 29 yearly task gives Feb 28 in non-leap years.
  - Completing a repeating task (maintainer's choice, 2026-10-30): the ticked task stays in Completed as history (without the rule), and a new copy appears on the next occurrence that is today or later, with the same content, tags and rule, and its subtasks unticked. Undo removes the copy. Changing the due date re-anchors the rule.
- **Reminders** (0 or more per task, see 3.3)
- **Notify on devices:** a set of registered devices. **Default = all devices.**
- Created/updated timestamps, soft-delete (tombstone) for sync

### 3.2 Views
- **List view:** groups: Overdue, Today, Tomorrow, This week, Later, No date, Completed (collapsible). Filter by category, priority, tag; search by text; sort options.
- **Weekly calendar view:** 7 columns, week starts on the day chosen in settings (**default Sunday**). Timed tasks placed at their time, all-day tasks in a top row. Swipe/arrow to previous/next week, "Today" button. Tap a day to add a task on that day. Drag a task to another day/time (desktop) — nice to have.
  - Same layout on every platform, phone included (maintainer's choice, 2026-10-30): header "Month Year · This week" and today's column outlined in the accent colour. **No hour timeline** (changed at the maintainer's request, 2026-10-30): each day column is a list of its tasks, all-day tasks first, then timed ones in time order, each chip showing its time above the title. Tap a day header or the empty part of a column to add a task that day. Upcoming repeats show faded.
- **Monthly calendar view** (added in M3 at the maintainer's request, all platforms): 6-week grid from the week-start day; task chips per day (coloured dots on narrow screens) with "+N"; tapping a day opens its agenda (side panel on wide screens, bottom sheet on phones). The Calendar tab switches between week and month.
- Quick add: a single input field on all views (title + Enter); details editable after.
- Task detail / edit screen or side panel (side panel on wide screens, full screen on phone).

### 3.3 Reminders
Two types, a task can mix both:

**Time reminder**
- Absolute (specific date & time) or relative to due time (e.g., 1 day before, 1 hour before, at due time). Multiple allowed.
- Repeating tasks: reminders follow each occurrence.
- Fires as a system notification on each device in the task's "Notify on devices" set (each device schedules its own local notifications after sync).
- Notification actions where the platform supports them: **Done**, **Snooze** (5 / 15 / 60 min, configurable).
- How M4 implements it (2026-10-31):
  - Plan computed by `planNotifications` in `shared` (14-day horizon; relative reminders in wall-clock time so DST doesn't move them; all-day tasks remind at a set time, default 09:00; repeats get reminders for each occurrence, including ones not created yet).
  - **iPhone:** iOS schedules them (`zonedSchedule`), the soonest 64. Done/Snooze open the app to run (foreground actions; no background isolate). Permission is asked when the first reminder is added.
  - **Windows / Linux:** the app shows them itself while running (Linux can't schedule; Windows can't cancel scheduled toasts without MSIX). Closing the window keeps it in the tray; one instance only; optional start on login (hidden). Reminders missed in the last 24 h show at startup.
  - Done on a future (projected) repeat isn't offered; Done on the real occurrence completes it (and spawns the next copy, reminders included).

**Location reminder (iPhone only)**
- Pick a place on a map (search address or drop a pin) or choose a saved place ("Home", "Work"...). Saved places are managed in settings.
- Trigger: **On arrive**, **On leave** — chosen per reminder.
- Radius: default **30 m**, adjustable per reminder (slider, e.g., 30–500 m).
- Optional: only active during a time window / on certain days (nice to have).
- Location reminders are created/edited on any device (map picker works on desktop too) but **only fire on the iPhone**. Desktop shows them in the task with a location icon.

**How location reminders work on iOS (important — implement this way):**
- iOS doesn't allow polling location every few minutes in the background. Use **Core Location region monitoring** (geofencing): iOS wakes the app when you cross a region boundary, even if the app is closed.
- iOS region monitoring is unreliable below ~100–150 m. To get ~30 m precision:
  1. Register an **outer geofence** of ~150 m around the place.
  2. When iOS wakes the app on entry into the outer region, start **high-accuracy location updates** for a short period (e.g., up to a few minutes, or until resolved).
  3. If the device comes within the configured radius (30 m) → fire the "arrive" notification and stop updates.
  4. For "leave": track whether the user was inside the 30 m radius; fire when they are clearly outside it (radius + accuracy margin), using the outer-region exit as a backup trigger.
  5. Respect battery: stop precise updates as soon as decided or after a timeout.
- iOS limit: max **20 monitored regions** per app. If there are more active location reminders, monitor the 20 nearest and re-evaluate when the user moves significantly (use significant-location-change monitoring).
- Required permissions: "Always" location, notifications. Write clear permission explanation texts in both languages. Handle the user denying "Always" gracefully (show a banner explaining location reminders won't work).
- Info.plist: location usage descriptions, `UIBackgroundModes` → `location`, `fetch`.
- Don't fire the same reminder repeatedly: debounce (e.g., don't re-fire "arrive" for the same reminder within X minutes; configurable; one-shot vs every time option).
- How M7 implements it (2026-11-05):
  - **Every time** (maintainer's choice): a location reminder fires each time its trigger happens while the task is open, at most once per 30 minutes; "arrive" needs a leave in between. No one-shot option and no time windows yet.
  - A reminder points to a saved place (`placeId`, so moving "Home" moves its reminders) or to a spot (`latitude`/`longitude` plus a `label`, schema v4). Deleting a place turns its reminders into spots. Radius 30-500 m; default radius is a synced setting.
  - Map picker: `flutter_map` + OpenStreetMap tiles; address search with Nominatim behind a swappable `Geocoder` (search on submit only, max 1 request/s, `User-Agent: Taskwise (+repo URL)`).
  - **iPhone, native Swift** (`app/ios/Runner/LocationReminder*.swift`, `GeofenceDecider.swift`): Dart hands the planned entries (`planLocationReminders` in `shared`, notification texts already localised) over the `taskwise/location` channel; Swift does region monitoring, the precise check and the notification itself, so nothing depends on Dart running after a background relaunch. The decisions live in `GeofenceEngine` (platform-free Swift in `GeofenceDecider.swift`); `LocationReminderManager` only connects it to Core Location. Outer region: arrive `max(150, r+100)` m, leave `max(100, r+70)` m. Entering it runs precise updates for up to 5 minutes. Arrive fires within the radius with a fix accurate to `max(r, 25)` m. "Outside" needs a fix accurate to 50 m or better and farther than `r + max(2 × accuracy, 20)` m, so one bad indoor fix doesn't count. Arrive is armed by being seen outside (a confirmed exit, a clearly-outside fix, or "outside" when monitoring starts), not by entering the outer region. An outer-region exit is confirmed with precise fixes first (iOS sometimes reports wrong exits); with no fix in 5 minutes iOS is believed. If a precise check runs out while the phone is near but not within the radius (e.g. chatting outside the house), a small "near" region (`max(50, r+20)` m) is watched so that walking in starts a new check. More than 20 reminders: the nearest are monitored and significant location changes re-pick them.
  - **Testing without the iPhone** (2026-11-05): `tools/geofence_sim/run.sh` runs the real `GeofenceEngine` with Swift in a podman container over 8 simulated walks (iOS-like region delays, noisy GPS, worse indoors, 300 random runs each); `run.sh test` runs the Swift unit tests (RunnerTests) on Linux. `app/integration_test/location_test.dart` drives the real app in a window on Fedora with real map tiles and address search. The simulator found and fixed three bugs before the first device test: a false "arrived" while sitting at home (one noisy indoor fix), a missed "arrive" after lingering near home for more than 5 minutes, and false "left"/"arrived" after a wrong exit from iOS.
  - Location notifications use the same category and payload as time reminders (Done, Snooze, tap open the task). Done completes the task as it is; Snooze comes back as a time notification.
  - Settings → Location reminders: saved places, default radius, and on the iPhone the permission status and a debug screen (watched areas, last position, the last 50 events).

### 3.4 Account & devices
- One account (username + password) on the server, created once with `POST /auth/setup` (setup page in the app). The server is public, so setup requires a long random **setup secret** set as a Vercel environment variable; without it, anyone could claim the account first. Setup is refused once an account exists.
- Each app install = a **device**. On first launch: enter server address, log in, give the device a name (pre-filled: "Windows PC", "Fedora Laptop", "iPhone"), device type is detected.
  - Changed in M6 (maintainer's choice, 2026-11-02): **signing in is optional**. The app opens straight to the tasks; a one-time banner and **Settings → Sync → Connect to your server** open the sign-in screen (server address, username, password, device name; a "First time? Create the account" link adds the setup secret and calls `/auth/setup`). Data already on a device is uploaded and merged when it first connects. Signing out revokes the device and keeps local data.
  - **Main device** (maintainer's request, 2026-11-02): the first device to sign in is the main device and manages the account's devices. Only it can remove or rename other devices and pass the role on (Settings → Sync → Devices → ⋯ → Make main device). Any device can rename itself and sign out. If the main device signs out or is removed, the most recently seen device takes over; if it is lost, any device can take the role with the account password ("Make this the main device"). Server rules in `docs/sync-api.md`.
- Server issues a per-device token (revocable). Store tokens securely (Windows Credential Manager / libsecret / iOS Keychain via `flutter_secure_storage`).
- **Settings → Devices:** list devices (name, type, last seen), rename, remove/revoke.
- New devices are added to "Notify on devices" for tasks that use the default "All devices" (store "all" as a flag, not as a list, so new devices are included automatically).
- Passwords hashed with a strong algorithm (argon2id or bcrypt). Rate-limit login, with the counters stored in the database (serverless functions keep no memory between requests).

### 3.5 Settings
- Theme: System / Light / Dark
- Language: English / Arabic (switches layout to RTL)
- Week starts on: Sunday (default) / Saturday / Monday
- Time format: 12h / 24h
- Default reminder (e.g., none / at due time / 15 min before) — M4: added when a task first gets a due time and has no reminders; synced.
- Default snooze durations — M4: pick up to 3 of 5/10/15/30/60/120 min (default 5/15/60); device-only. Plus the all-day reminder time and, on desktop, keep running in background / start on login.
- Default location radius (30 m)
- Saved places
- Categories (add, rename, color, delete)
- Server: address, connection status, last sync, "Sync now", log out
- Devices (see 3.4)
- Export / import data as JSON (backup)
- About (version, license, GitHub link)

### 3.6 Design
- Simple and clean. Light and dark mode with a single accent color (user can pick from ~6 accents — nice to have).
- Material 3 base, rounded corners, generous spacing, good typography. Use a font that supports Arabic well (e.g., Noto Sans + Noto Sans Arabic, or IBM Plex Sans Arabic).
- **Designs (M8):** four complete designs, picked per device in Settings → Appearance → Design. Each has its own screens (`app/lib/ui/designs/<name>/`, see `docs/architecture.md`); screenshots in `design/<name>/`.
  - **Classic:** the original (teal, Noto Sans + Noto Sans Arabic).
  - **Lapis** (Opus 5.5): ink blue on cool grey, saffron for "today", a wide desktop side bar with keyboard shortcuts; IBM Plex Sans Arabic.
  - **Slate & Indigo** (Gemini 3.8 Flash): indigo, cards, a daily progress bar; Noto fonts.
  - **Brutal** (Opus 5.5, neo-brutalism, **the default**): cream paper, 2 px ink outlines, hard shadows, flat yellow/tomato/lilac/mint/cobalt blocks; dark mode is "warm charcoal"; Space Grotesk + Alexandria. The app icon is Brutal's.
- **Simple hover animations** on desktop: subtle background/elevation change on task rows and buttons (~150 ms), smooth check animation when completing a task, gentle slide/fade for panels. Respect "reduce motion" settings.
- Responsive: phone layout (bottom nav: Tasks / Calendar / Settings), desktop layout (side nav + optional detail panel).
- Accessible: proper contrast in both themes, readable sizes, screen-reader labels.

---

## 4. Sync design

- **Local-first:** every device has its full local SQLite DB and works offline. Sync is background and automatic.
- Every record (task, subtask, reminder, category, place, setting) has: `id` (UUID v4/v7), `updatedAt` (hybrid logical clock or server-assigned sequence), `deleted` flag, `updatedByDevice`.
- Server keeps a monotonically increasing **change sequence number**. Clients:
  - **Push:** send all local changes since last successful push.
  - **Pull:** `GET /sync?since=<seq>` returns all changes after that sequence.
- Conflict rule: **last write wins per record** (good enough: single user, one device at a time). Keep it simple, but structure code so field-level merge could be added later.
- Tombstones: deleted records sync as `deleted=true`; a daily cron job purges tombstones older than 90 days.
- Sync triggers: app start/resume, after any local change (debounced ~2 s), every 1–2 min while app open, iOS background refresh, iOS geofence wake (if quick), manual "Sync now".
- After each pull, each device **rebuilds its scheduled local notifications** for tasks targeted at that device (cancel stale ones, schedule new ones; iOS has a 64 pending-notification limit — schedule the soonest 64 and refresh on sync/app open).
- Device-only settings (theme, language, etc.) can be local; shared data (categories, places, week start) syncs. Decide per setting and document it.
  - Decided in M6: **synced** settings are week start and the default reminder. **Device-only**: theme, language, time format, snooze options, all-day reminder time, the desktop background options, and the sync bookkeeping (server address, last pulled sequence number).
- How M6 implements it (2026-11-02):
  - An **outbox** table (`sync_outbox`, schema v2) is filled by SQLite triggers on every synced table, so no write can forget to queue itself; the v1→v2 migration queues all existing rows.
  - `SyncEngine` (`app/lib/sync/`) pushes the outbox in batches of 500, pulls pages until up to date (same last-write-wins rule as the server; an unpushed newer local edit is kept), handles `410` with a full resync, and copies the device list from `GET /devices`. `SyncController` runs it at start, on resume, 2 s after a local change, every minute and on "Sync now"; a revoked token shows "Signed out".
  - The token is kept with `flutter_secure_storage` (Credential Manager / GNOME keyring / iOS Keychain).
  - **iOS background refresh (M7):** `workmanager` runs a background-refresh task (`io.github.krkr8.taskwise.sync`) in a second Flutter engine when iOS allows it: one sync, then the time notifications and the watched places are re-planned (`app/lib/background/background_sync.dart`). The token is stored "after first unlock" so it can be read while the phone is locked (older tokens are moved over on the next read). Location events themselves need no sync: they are handled natively.
- API: JSON over HTTPS, versioned (`/api/v1/...`), token auth in header. Endpoints at minimum: `POST /auth/login`, `POST /auth/setup`, `GET/POST /sync`, `GET/PATCH/DELETE /devices`, `GET /health`. Documented in `docs/sync-api.md`, with JSON fixtures in `shared/test/fixtures/` tested on both sides.
- The server is public on the internet (Vercel always serves HTTPS). Every endpoint except `/health`, `/auth/login` and `/auth/setup` requires a valid device token.
- Server backups: the database provider's own backups, plus a daily cron export of all records, keeping the last N. Each device also holds a full copy of the data (local-first), and JSON export is available.

---

## 5. Milestones

Each milestone ends with: tests passing, commit + push, Progress Log updated, and test instructions given to the maintainer.

### M0 — Project setup
- Check/install tools on Fedora: Flutter SDK (Linux desktop deps: clang, cmake, ninja, gtk3-devel, etc.), Git, GitHub CLI. Give the maintainer exact `dnf` commands; don't run `sudo` commands without asking.
- Create repo structure (`app`, `server`, `shared`, `docs`), license, README, `.gitignore`, analysis options, formatting.
- Basic GitHub Actions: analyze + tests on every push.
- **Done when:** `flutter run -d linux` shows a placeholder home screen; CI is green.

### M1 — Core app (local only)
- Data model + drift DB in `shared`/`app` (tasks, subtasks, categories, tags, reminders, places, devices, settings) with migrations.
- List view, quick add, task detail/edit, complete/uncomplete, delete (with undo snackbar), subtasks, priority, categories, search & filters.
- Settings: theme (light/dark/system), language EN/AR with RTL, week start, time format.
- Design system: colors, typography, spacing, hover animations, responsive layout.
- **Done when:** maintainer can fully manage tasks on Fedora, in both languages and themes; unit tests for model logic.

### M2 — Build pipeline for all platforms (de-risk iOS early)
- GitHub Actions: build Windows (.zip or MSIX/installer), Linux (tar.gz; AppImage or RPM nice to have), and **unsigned iOS .ipa** on a macOS runner. Upload as artifacts / release on tag.
- Configure iOS project: bundle ID, display name, icon placeholder, Info.plist permissions, background modes.
- Write `docs/install-ios-sidestore.md` (step-by-step for a beginner, Windows or Linux based), `docs/install-windows.md`, `docs/install-linux.md`.
- Confirm (and write down) which capabilities work with a free Apple ID.
- **Done when:** the maintainer has the M1 app running on Windows machine, Linux machine, and iPhone.

### M3 — Weekly calendar view + recurrence
- Weekly view per 3.2 (respects week-start setting and RTL).
- Monthly view per 3.2 (added 2026-10-30 at the maintainer's request).
- Recurrence rules per 3.1, with editor UI and solid tests (DST, month ends, leap years, "2nd Tuesday", timezone Asia/Baghdad and others).
- **Done when:** repeating tasks show correctly in list and week view on all devices.

### M4 — Time reminders & notifications
- Time reminders (absolute + relative, multiple per task), scheduling engine in `shared` (pure, tested), platform notification layer.
- Notification actions Done / Snooze where supported; tapping a notification opens the task.
- iOS 64-pending limit handling; reschedule on app start and data change.
- Windows: notifications even when the window is closed → minimize to system tray + start on login option. Linux (GNOME): same, with a background/autostart option (document GNOME tray limitations; use a background mode if no tray).
- **Done when:** reminders fire reliably on all three devices (maintainer tests with a list you provide).

### M5 — Sync server
- First, verify the current free limits of Vercel Hobby and the database (Turso preferred, Neon as fallback), and tell the maintainer.
- Replace the Dart placeholder in `server/` with a TypeScript + Hono server per sections 2 and 4: setup (with setup secret), login with rate limiting, devices, sync endpoints, hosted database with migrations, logging, Vercel Cron job (tombstone purge, daily backup export). Configuration only through environment variables (database URL and token, setup secret); never commit secrets.
- Write `docs/sync-api.md` and the shared JSON fixtures in `shared/test/fixtures/`; contract tests on both sides (Dart and TypeScript) load the same fixtures.
- Integration tests for the sync protocol against a local SQLite/libSQL database.
- The same server code also runs as a plain Node server with a Dockerfile (for self-hosters).
- CI: add a Node job that type-checks and tests the server.
- `docs/server-setup-vercel.md`: beginner steps from Fedora (create Vercel and database accounts, install the `vercel` CLI, set environment variables, deploy, find the server address).
- **Done when:** the server is deployed on Vercel and `GET /api/v1/health` works over HTTPS from the Linux machine and from the iPhone on mobile data.

### M6 — Client sync + accounts + device targeting
- First-launch flow: server address → login → name device. Secure token storage.
- Sync engine per section 4, sync status indicator, "Sync now", offline queue.
- Settings → Devices (list, rename, revoke).
- "Notify on devices" selector on tasks (default All), and each device only schedules notifications for tasks targeted at it.
- **Done when:** a task created on any device appears on the others within ~1–2 minutes, and device targeting works.

### M7 — Location reminders (iPhone)
- Map place picker (search + pin + radius circle preview), saved places management (works on all devices).
- iOS geofencing per section 3.3 (outer 150 m region + precise check for 30 m, arrive/leave, 20-region limit handling, debounce).
- Permission flow and explanations (EN/AR).
- Desktop: show location reminders read-only-trigger (editable, but never fire).
- Give the maintainer a real-world test plan (walk away from/to home, etc.) and a debug screen showing monitored regions and last events.
- **Done when:** arrive and leave reminders fire on the iPhone at ~30 m, with the app closed.

### M8 — Design, polish & open-source readiness
- **Start by asking the maintainer for their design idea** (they asked for a design milestone on 2026-10-30 and have an idea ready). Plan the redesign with them before anything else in this milestone.
- Animation polish, empty states, onboarding hints, app icon, accent colors.
- JSON export/import, error handling, logs viewer.
- Performance check (1,000+ tasks).
- README with screenshots, CONTRIBUTING, self-hosting guide, versioned GitHub Releases.
- **Done when:** maintainer signs off.

### M9 — Linux AppImage
- Asked for by the maintainer on 2026-11-07 (after M8): an AppImage that runs on Debian/Ubuntu and Arch too. The tar.gz with `install.sh` stays.
- Built on Ubuntu 22.04 (glibc 2.35) in the release workflow by `tool/package_appimage.sh` (pinned appimagetool 1.9.1 and type2 runtime 20251108, SHA-256 checked). Bundles libsecret; GTK 3, Mesa and glibc come from the system. `patchelf` gives bundled libraries `$ORIGIN` as RUNPATH.
- "Start when I log in" points at `$APPIMAGE`, not the temporary mount.
- `tool/appimage_smoke_test.sh` starts the AppImage in podman on Debian 12, Ubuntu 22.04/24.04 and Arch.
- **Done when:** the AppImage starts on those four and on Fedora.

### M10 — Android
- Asked for by the maintainer on 2026-11-07: an Android app with everything the iPhone has, location reminders included (native Kotlin, same rules as iOS). Tested on the emulator only (no Android phone).
- **Done when:** the release APK runs on the emulator: time reminders with the app closed, sync, backup, and arrive/leave reminders on a simulated walk.

---

## 6. Maintainer's preferences (summary)
- Single user now; maybe public open-source self-hosted later.
- Sync server hosted free on Vercel, reachable from anywhere over HTTPS; the maintainer doesn't maintain or secure servers. No server on the Windows machine.
- Location reminders only on iPhone; default radius 30 m; arrive/leave selectable.
- Week starts Sunday by default, changeable in settings.
- English + Arabic, switchable in settings.
- Notifications on all devices by default, selectable per task.
- Simple design, light/dark mode, subtle hover animations. Several complete designs to choose from in Settings (Brutal by default); the maintainer accepted that screen changes may have to be made in each design.
- The maintainer is comfortable with the terminal but not a mobile developer — explain device-side steps clearly.

---

## 7. Progress Log

### Where we left off (2026-11-07)
- **Status for a new chat:** M8 was signed off (2026-11-07). The maintainer then asked for two more milestones (§5): **M9 Linux AppImage** (built, v0.6.1) and **M10 Android** with location reminders (next; plan approved 2026-11-07, emulator testing only). Ask the maintainer for the v0.6.1 AppImage result, and work on M10.
- **Android toolchain on the Linux machine:** Android builds need a full JDK 21 (`sudo dnf install -y java-21-openjdk-devel`, then `flutter config --jdk-dir /usr/lib/jvm/java-21-openjdk`). Only the Java 25 *runtime* is installed, without `javac`/`jlink`. `flutter config --enable-android` is on. The emulator is `Pixel_9_API_36` (google_apis, x86_64).
- **The repo is public** (2026-11-07). It was recreated on GitHub with a clean history: every commit is by `Krkr8` with the GitHub noreply email, and LICENSE says Krkr8. Don't put the maintainer's name, email or server address anywhere (commits, docs, the repo's homepage field). The docs say "the maintainer" and name no devices or server details. v0.6.0 is published (the earlier drafts were lost with the old repo). Vercel's GitHub app has access to the new repo, and pushes to `main` deploy again.
- v0.3.1 was confirmed on all devices (2026-11-05); v0.3.2 made the Undo bar fade after 5 seconds.
- **Things to watch in the M7 device test** (all untestable without the phone):
  - Region events with the app swiped away (iOS relaunches it in the background; `LocationReminderManager` starts in `AppDelegate`).
  - Precise updates started from the background need "Always" location access.
  - "Leave" fires after iOS reports leaving the ~100 m outer region (plus iOS's delay, often 20 s to 3 min), so usually 150-400 m from home on foot. The maintainer should know this; continuous tracking at home would drain the battery.
  - Background sync: iOS decides when it runs (rarely for a sideloaded app that's seldom opened). Settings → Sync's "Synced …" time shows whether it ran.
- **Server:** deployed on Vercel (Root Directory `server`, Node 24) with a Turso database. Pushes to `main` deploy automatically. The server address and secrets are only in the maintainer's `~/.config/taskwise/server-secrets.env` (never in the repo). The account exists.
- **Release files:** the release workflow builds drafts; Claude Code downloads them for the maintainer with `gh release download v<version> --dir ~/Downloads/taskwise-<version>`. The maintainer copies the Windows zip to the Windows machine (or downloads it from the draft release while signed in to GitHub), and installs the .ipa with iloader → Import IPA.
- **iPhone install:** with iloader from the Linux machine (SideStore sign-in is broken by Apple since 2026-10-12, error -80045). Refresh every 7 days with iloader → Import IPA. See `docs/install-ios-sidestore.md`.
- Running app tests on the Linux machine: take ccache off `PATH` (see `docs/dev-setup-fedora.md`), and re-run if a file fails with "Unable to connect to flutter_tester process" (or use `--concurrency=1`). The live sync test needs a local server: see the comment at the top of `app/test/sync/live_server_test.dart`.

| Milestone | Status | Date | Notes |
|---|---|---|---|
| M0 Project setup | ✅ Done | 2026-10-20 | Flutter 3.47.7 workspace (app/server/shared), placeholder screen, CI green. |
| M1 Core app | ✅ Done | 2026-10-20 | Local-only task manager: drift DB, list/quick add/details, subtasks, categories, tags, search/filter/sort, EN/AR with RTL, light/dark. 67 automated tests. Maintainer-tested on Fedora. |
| M2 Build pipeline | ✅ Done | 2026-10-30 | Release workflow builds Linux, Windows and unsigned iOS into a draft v0.1.0 release. Maintainer-tested on Fedora, Windows and iPhone. The iPhone app is installed with iloader from the Linux machine, because Apple blocks SideStore's own sign-in (-80045) since 2026-10-12. Also fixed from iPhone testing: tapping outside a text field (or scrolling) closes the keyboard, and selected Settings options use the accent colour. 69 automated tests. |
| M3 Calendar + recurrence | ✅ Done | 2026-10-30 | Calendar tab with week (7 day columns listing tasks, all-day first then by time) and month views on all platforms; repeating tasks (RRULE subset in `shared`, editor with presets and Custom, done copy + next occurrence with Undo); upcoming repeats shown faded in the calendar. Selected chips now clearly highlighted. 115 automated tests (shared tests run in 3 timezones in CI). |
| M4 Time reminders | ✅ Done | 2026-10-31 | Time reminders (relative + absolute, several per task, follow repeats), scheduling engine in `shared`, notifications with Done/Snooze/open, iOS 64-limit scheduling, desktop tray + single instance + start on login, notification settings. A real reminder fired on Fedora (GNOME) with Done/Snooze buttons. Closed by the maintainer on 2026-10-31 before device tests: **Windows and iPhone are untested** (see Where we left off). 138 automated tests. |
| M5 Sync server | ✅ Done | 2026-11-02 | TypeScript + Hono server in `server/` (Node 24): account setup with a setup secret, login (argon2id) with database-backed rate limiting, per-device tokens (SHA-256 stored, revocable), devices API, push/pull sync with last-write-wins and a change sequence, daily Vercel Cron (90-day tombstone purge with task children, 7 nightly backups in the database). Generic record store: the server doesn't interpret records. API in `docs/sync-api.md`; contract fixtures in `shared/test/fixtures/sync/` tested by both Dart and TypeScript. Runs on Vercel or Docker (built and run with Podman locally). Dart `server/` placeholder removed; CI has a Node job. Free limits checked 2026-10-31 (Vercel Hobby: 1 M invocations/month, cron daily; Turso Free: 5 GB, 500 M reads, 10 M writes). 228 automated tests (app 53, shared 106, server 69). Deployed on Vercel (`fra1`) with Turso (`aws-eu-central-1`); health checked over HTTPS from the Linux machine and from the iPhone on mobile data. |
| M6 Client sync + devices | ✅ Done | 2026-11-03 | Optional sign-in from Settings (with account setup), one-time banner, sync engine (trigger-filled outbox, push/pull with last-write-wins, full resync on 410, device list), sync triggers (start, resume, 2 s after changes, every minute, Sync now), status icon, Settings → Sync and → Devices, sign out, "Notify on" per task with each device scheduling only its own reminders. Maintainer-tested v0.3.0: sync connects on Fedora, Windows and iPhone. Closed with the v0.3.1 fixes (Windows scrolling and tray Quit, iOS rescheduling bug, test-notification button, "time passed" reminders) and the **main device** (manages the other devices). Database schema v3. Live test: two app devices through the real TypeScript server (also in CI). 276 automated tests (app 85 incl. 1 live, shared 112, server 79). v0.3.1 confirmed by the maintainer on all devices (2026-11-05); v0.3.2 makes the Undo snackbar fade after 5 s. |
| M7 Location reminders | ✅ Done | 2026-11-06 | Map picker (flutter_map + OSM, Nominatim search behind a swappable `Geocoder`), saved places, location reminders on every device (Arrive / Leave, 30-500 m, fire every time, 30 min debounce), schema v4 (`reminders.label`). iPhone: native Swift geofencing (outer region + precise check, 20-region limit, debug screen), permission explanation and banner (EN/AR, Arabic `InfoPlist.strings`). iOS background refresh sync with `workmanager` 0.10.10; token readable after first unlock. New iOS CI workflow runs the Swift tests. 300 automated tests (app 102 + 1 live, shared 119, server 79) + 9 Swift tests. v0.4.1: `GeofenceEngine` + walk simulator, 3 geofencing bugs fixed, Linux integration test; 16 Swift tests. Closed by the maintainer without the iPhone walk test (skipped). |
| M8 Design + polish | ✅ Done | 2026-11-07 | Design tour screenshots; Opus/Gemini design contest; four designs selectable per device (Classic, Lapis, Slate & Indigo, Brutal default with warm charcoal dark mode); UI split into `ui/shared` + `ui/designs/<name>`; `docs/architecture.md`. v0.6.0: centred Settings, cloud button syncs, JSON backup export/import, logs viewer + error logging, 2,000-task performance test (Opus subagent) with lazy lists, README/CONTRIBUTING/self-hosting/CHANGELOG (Sonnet subagent), whole-word titles in the phone week view. 405 automated tests (app 207 + 1 live, shared 119, server 79) + 16 Swift tests; 3 Linux integration tests (location, design tour, performance). Signed off by the maintainer on 2026-11-07. |
| M9 Linux AppImage | ✅ Built (v0.6.1) | 2026-11-07 | `taskwise-<v>-linux-x86_64.AppImage` next to the tar.gz, both built on Ubuntu 22.04. Bundles libsecret (RUNPATH fixed with patchelf, since plugins load it); pinned appimagetool and runtime. Start on login uses `$APPIMAGE`. Smoke test in podman: starts on Debian 12, Ubuntu 22.04, Ubuntu 24.04 and Arch; also run on Fedora with FUSE. Minimal Debian/Ubuntu installs need `libegl1 libgles2` (Flutter loads them; every desktop has them). 408 automated tests (app 210 + 1 live, shared 119, server 79). |

### How to test the latest milestone
**M9 (AppImage), with v0.6.1.** Files in `~/Downloads/taskwise-0.6.1/` on the Linux machine.

1. Quit the installed Taskwise (tray → **Quit Taskwise**).
2. Run the AppImage:
   ```bash
   chmod +x ~/Downloads/taskwise-0.6.1/taskwise-0.6.1-linux-x86_64.AppImage
   ~/Downloads/taskwise-0.6.1/taskwise-0.6.1-linux-x86_64.AppImage
   ```
   Taskwise opens with your tasks (the AppImage uses the same data as the installed app). Settings → About says 0.6.1.
3. Turn on **Settings → Background → Start when I log in**, then run `grep Exec ~/.config/autostart/Taskwise.desktop`. It shows the AppImage's path in `~/Downloads/...`, not `/tmp/.mount_…`. Log out and in: Taskwise starts in the background. (Turn it off again afterwards if you prefer the installed app.)
4. If you have a Debian, Ubuntu or Arch machine (or a friend with one), try the AppImage there too.
5. The tar.gz still works as before (`./install.sh`).

**Earlier: M8 (backup, logs, speed, fixes), with v0.6.0.** Files in `~/Downloads/taskwise-0.6.0/` on the Linux machine. Fedora: `git pull`, then `cd app && flutter run -d linux`. Windows: quit Taskwise (tray → Quit), unzip the new zip over the old folder. iPhone: iloader → Import IPA → `taskwise-0.6.0-ios-unsigned.ipa`. Your tasks and sign-in are kept.

1. **Settings on a wide window:** maximise Taskwise and open Settings. It sits in the middle, with the scroll bar at the right edge.
2. **Cloud button:** in the side bar (desktop) or the top bar (phone), tap the cloud. It turns into the syncing icon for a moment, and Settings → Sync says "Synced just now". It no longer opens Settings.
3. **Export:** Settings → Backup → **Export to a file**.
   - Fedora/Windows: pick a folder and save. A message shows where the file went.
   - iPhone: the message says it's in the **Files** app → **On My iPhone** → **Taskwise**. Open the Files app and check the file is there.
4. **Import:** delete a task (and don't press Undo). Then Settings → Backup → **Import from a file**, and pick the file from step 3. The task comes back, and the message counts what was added. After a minute it's back on your other devices too.
5. **Logs:** Settings → About shows "Taskwise 0.6.0". Tap **View logs**: you see lines like "Synced: …". Try **Problems only**, and the copy button. No task titles appear in the logs.
6. **Phone week view:** Calendar → week on the iPhone. Long words end with "…" instead of breaking in the middle.
7. **Speed:** scrolling the task list and switching tabs should feel instant, in every design.
8. Tell me what you think. If everything is fine, say so and **M8 is done**.

**Earlier: M8 step 1 (designs), with v0.5.0.** Files in `~/Downloads/taskwise-0.5.0/` on the Linux machine. Fedora: `git pull`, then `cd app && flutter run -d linux`. Windows: quit Taskwise (tray → Quit), unzip the new zip over the old folder. iPhone: iloader → Import IPA → `taskwise-0.5.0-ios-unsigned.ipa`. Your tasks and sign-in are kept.

1. Taskwise opens in the **Brutal** design (cream paper, black outlines). The app icon is new too (on Windows and the iPhone it may take a restart or a minute to refresh).
2. **Settings → Appearance → Design:** tap **Classic**, **Lapis**, **Slate & Indigo** and **Brutal** in turn. The whole app changes at once and stays on Settings.
3. In each design, look at Tasks, open a task, the Calendar (week and month) and Settings. Try **Theme → Dark** and **Language → العربية** too.
4. Close and reopen Taskwise: it keeps the design you chose. Each device keeps its own (try a different one on the iPhone).
5. Desktop shortcuts in Lapis and Brutal: **Ctrl+N** new task, **Ctrl+F** search, **Esc** closes the open task.
6. Tell me which design you keep using, and anything that looks wrong (a screenshot in `tempscreenshot/` helps).

**M7 (location reminders), with v0.4.1.** Files in `~/Downloads/taskwise-0.4.1/` on the Linux machine. Fedora: `git pull`, then `cd app && flutter run -d linux`. Windows: unzip the new zip over the old folder. iPhone: iloader → Import IPA → `taskwise-0.4.1-ios-unsigned.ipa`. Quit Taskwise first everywhere (tray → Quit). Your tasks and sign-in are kept.

*At home, on Fedora (or Windows):*
1. **Settings → Location reminders → Saved places → Add place.** Type your street or area in the search box and press Enter (or the arrow), pick a result, then tap the map exactly on your front door. Name it "Home" and press **Save**. Optionally add "Work" or a shop the same way.
2. Make a task "Test: arrive home". **Add reminder → At a location…** → tap the **Home** chip → **Arrive** → **Save**. The task shows "Arrive at Home · 30 m", a 📍 in the list, and "Only reminds on the iPhone".
3. Make a task "Test: leave home" with a location reminder at Home, **Leave**.
4. Within a minute or two both tasks appear on the iPhone (or open Taskwise there).

*On the iPhone:*
5. Open Taskwise and one of the two tasks. If Taskwise asks about location: read the explanation, press **Continue**, choose **Allow While Using App**, and when iOS asks again, **Change to Always Allow**. If it never asks for "Always": iPhone **Settings → Taskwise → Location → Always**, and turn **Precise Location** on.
6. **Settings → Location reminders → Location debug:** "Location access: Always", 2 location reminders, and both watched areas listed. Keep this screen in mind: it shows what happened if a reminder doesn't fire.
7. Swipe Taskwise away (close it completely). Lock the phone.

*The walk (the real test):*
8. **Leave:** walk (or drive) away from home, at least 200 m. "Test: leave home · You left Home" appears, usually 150-400 m from home (iOS takes a moment to notice).
9. **Arrive:** come back. "Test: arrive home · You're at Home" appears when you're close to the door, about 30 m. Press **Done** on it: the task is ticked off.
10. Open **Location debug** and press refresh: the events list shows "enter", "precise on", "notify …". Please send a screenshot of it, especially if something didn't fire or fired at the wrong place.
11. Make a third task with **Arrive** at a shop or a friend's place (search it on the map). Next time you go there, it reminds you. It reminds again on later visits until you tick the task off.

*Background sync (needs a few hours):*
12. Leave Taskwise closed on the iPhone. On Fedora, make a task with a time reminder for this evening. Without opening Taskwise on the iPhone, it may still remind you: iOS lets Taskwise sync in the background now and then (iOS decides when; sometimes only after you've used the app for a few days). Afterwards, Settings → Sync on the iPhone shows when it last synced.

Also on Windows/Fedora: Settings → **Default radius for location reminders** changes on all devices.

**M6 (sync), with the v0.3.0 build.** Fedora: `git pull`, then `cd app && flutter run -d linux` (needs `sudo dnf install -y libsecret-devel` once). Windows and iPhone: install v0.3.0 from the draft release (as in `docs/install-windows.md` and `docs/install-ios-sidestore.md`). Quit any running Taskwise first (tray menu → Quit) so the new version starts.

1. **Fedora first, to create the account:** Tasks shows a banner "Sync your devices…". Click **Connect**.
   - Server address: your Vercel address (in `~/.config/taskwise/server-secrets.env`, `SERVER_URL`).
   - Click **First time? Create the account**, paste the setup secret (`SETUP_SECRET` in the same file), choose a username and a password of at least 10 characters, keep the device name, and press **Create account and sign in**.
   - The banner disappears, and a cloud icon with a tick appears at the bottom of the side bar. **Settings → Sync** says "Synced just now".
2. **Windows, then iPhone:** Connect with the same address, username and password (not the "first time" link). Your existing tasks from each device are merged.
3. Make a task on one device. Within about 1–2 minutes (or press **Sync now** in Settings, or switch away and back to the app) it appears on the others. Try editing, completing and deleting too.
4. **Settings → Week starts on** changes on all devices. Theme and language stay per device.
5. **Settings → Sync → Devices:** all three devices are listed. Rename one; remove none yet.
6. **Notify on:** open a task with a reminder 5 minutes ahead and under **Notify on** untick everything except the iPhone. Only the iPhone reminds; on the others the 🔔 becomes a crossed-out bell.
7. **Offline:** turn the Linux machine's Wi-Fi off, edit a task (the cloud icon shows offline), turn it on: the change arrives on the other devices.
8. **Sign out** on one device (Settings → Sync): its tasks stay; it no longer syncs, and it is gone from the Devices list on the others.

Also run the **M4 list below on Windows and the iPhone** with this build (reminders were never tested there).

**M5 (sync server).** Follow `docs/server-setup-vercel.md` step by step. In short:
1. `git pull`. Make the setup and cron secrets (step 1) and keep them in your password manager.
2. Create the Turso database and copy its URL and token (step 2).
3. Import the repo in Vercel with **Root Directory = `server`**, add the four environment variables, deploy, and set the function region near the database (step 3).
4. From the Linux machine, run `curl https://<your-app>.vercel.app/api/v1/health`. It should print `{"status":"ok","apiVersion":1,…}`.
5. On the iPhone, turn Wi-Fi off and open the same address in Safari. You should see the same text.
6. Optional: create your account with the `curl` in step 5 of the guide. A second try should say "The account already exists".
7. Tell Claude Code the result (and the error text or Vercel **Logs** if something fails).

Local checks (optional): `cd server && npm ci && npm test`. To run the server on the Linux machine: `cp .env.example .env && npm run dev`, then `curl http://localhost:8787/api/v1/health`.

**M4.** Fedora: `git pull`, then `cd app && flutter run -d linux`. Windows and iPhone: the next release build (v0.2.0).

On every device:
1. Open a task, give it a due date and a time about 5 minutes from now. Under **Reminders**, tap **Add reminder → 5 minutes before** (and try **At due time** too). The row shows a 🔔.
   - iPhone: allow notifications when asked.
2. Wait. A notification "Task title / Due: Today, …" appears with **Done** and **Snooze** buttons.
3. Press **Snooze 5 minutes**: it comes back 5 minutes later. Press **Done**: the task is ticked off.
4. Tap a notification (not a button): Taskwise opens on that task.
5. **Repeating task:** make a daily task with a reminder, tick it off. Tomorrow's copy has the same reminder.
6. **Custom date & time…** in Add reminder: pick a time 2 minutes away; it fires.
7. **Settings → Notifications:** set Default reminder to "15 min before", then give a new task a time: the reminder is added by itself. Change the snooze options and check the buttons change.

Desktop (Windows and Fedora):
8. Close the window with a reminder pending: it still fires (Taskwise stays in the tray). Open Taskwise again from the menu: the same window comes back.
9. Tray menu → **Quit Taskwise**, set a reminder 1 minute ahead next time and start Taskwise after it was due: it shows as missed when the app starts.
10. **Settings → Background → Start when I log in**, log out and in: Taskwise is running in the background.
    - Fedora tray icon needs `sudo dnf install -y gnome-shell-extension-appindicator` (see `docs/install-linux.md`).

iPhone only:
11. Close Taskwise completely (swipe it away) with a reminder pending: it still fires.

Automated checks (optional): from the repo root, run `flutter analyze`, then `cd app && flutter test`, `cd ../shared && dart test` and `cd ../server && npm ci && npm test`. If `flutter test` fails with "Building native assets failed", see the ccache note in `docs/dev-setup-fedora.md`.

### Known issues
- **iPhone:** SideStore can't sign in to Apple right now (-80045/-80046, Apple-side change from 2026-10-12). Taskwise is installed and refreshed weekly with iloader over USB instead. See Troubleshooting in `docs/install-ios-sidestore.md`.
- **Please review the Arabic text** (`app/lib/l10n/app_ar.arb`). Claude Code wrote the translations, and a native speaker should check them (M3 added the repeat and calendar texts, including Arabic plural forms; M7 added the location texts and `ios/Runner/ar.lproj/InfoPlist.strings`).
- **Location reminders:** "Leave" usually fires 150-400 m from the place on foot (after iOS reports leaving the ~100 m watched area), not at the 30 m radius. If you stand 30-50 m from the place's pin for more than 5 minutes (e.g. in the car in the driveway), "arrive" may not fire until you leave and come back. Accuracy indoors and in dense streets can be worse than 30 m; the debug screen shows the last position's accuracy. The map and address search need internet.
- `flutter pub get` reports that some packages "have newer versions incompatible with dependency constraints". This is expected and comes from the version pins below.
- Grouping is by date only: a task due at 9:00 today stays in **Today** after 9:00 rather than moving to Overdue. Its due label shows the time.
- The sort choice and collapsed groups reset when the app restarts (kept in memory only).
- Running `flutter run`/`build` from the repo root fails with `Target file "lib/main.dart" not found`. Run them from `app/`.
- GTK prints harmless `Atk-CRITICAL` / cursor-theme warnings to the terminal on GNOME.

### Notes for later
- **`test` is pinned to 1.31.1** because Flutter 3.47.7's `flutter_test` pins `test_api` 0.7.12, and a pub workspace resolves to one version. Whenever Flutter is upgraded, bump `test` (in shared) to the release that uses the new `test_api`. The same constraint caps `analyzer` below 14, which keeps `build_runner` at 2.15.x.
- Flutter's version is pinned in two places: `.github/workflows/ci.yml` and `docs/dev-setup-fedora.md`. Keep them in sync.
- GitHub notice (2026-10-20): the `ubuntu-latest` runner label is moving to Ubuntu 26 (from 2026-10-19). Consider pinning an explicit runner image in M2.
- **M2:** the Windows SmartScreen step in `docs/install-windows.md` is untested (the zip was unblocked first). macOS runners can be unavailable for a while ("job was not acquired"); just re-run the release workflow later.
- **iOS signing:** Apple broke free sideloader sign-in in October 2026 (SideStore -80045/-80046, workaround in `docs/install-ios-sidestore.md`). If free sign-in keeps breaking, consider the paid Developer Program + TestFlight (signing and upload in the release workflow, App Store Connect API key as GitHub secrets).
- **Calendar (later):** drag a task to another day (desktop) is still a "nice to have".
- **Repeats:** un-ticking an old done copy from Completed makes it a normal one-off task (its rule moved to the next copy). Rules are an RRULE *subset*; anything else from a future import should be validated with `RecurrenceRule.tryParse`.
- **Local test runner:** `flutter test` sometimes fails to start one test file with "Unable to connect to flutter_tester process" on the Linux machine. It's the runner, not the code; re-run, or use `flutter test --concurrency=1`.
- **Reminders (later):** Done/Snooze on iOS open the app; handling them in the background needs a background isolate with its own database connection. iOS snooze buttons are registered at launch, so changed snooze options apply on iOS after restarting the app. Windows `cancel` of shown toasts needs MSIX packaging. The first iPhone/Windows builds with `tray_manager` (which builds `cnativeapi` native code, iOS included) are untested; check the v0.2.0 release run.
- **M6:** after a sync pull, the reminder scheduler re-plans automatically (it watches the tasks and reminders streams). The default reminder setting is marked synced.
- **Vercel entry file:** Vercel uses the first file among `app.ts`, `index.ts`, `server.ts`, `src/app.ts`, `src/index.ts`, `src/server.ts` that imports `hono` itself. So the app factory lives in `src/api.ts` (not `app.ts`), and `src/index.ts` keeps a value `import { Hono } from 'hono'`. Both mistakes broke the first deploys (FUNCTION_INVOCATION_FAILED, then "No entrypoint found which imports hono").
- **M5 versions:** TypeScript is pinned to 6.0.3, because 7.0 (the new native compiler) was released on 2026-10-31 itself; move to 7.x once it has settled. `npm install` warns that esbuild's postinstall script (used only by the `tsx` dev runner) isn't approved; it works without it.
- **Sync (later):** `flutter_secure_storage` is pinned to 10.0.0 because 11.x needs `win32` 6, while `launch_at_startup` 0.5.1 (start on login) still needs `win32` 5. Move up when `launch_at_startup` does. When two devices had categories or tags with the same name before connecting, both copies are kept (merge them by hand). Signing in to a different server re-uploads everything.
- **Account (later):** changing the account password isn't possible yet (only by resetting the database). The main device would be the natural place for it.
- **Done in M6, for reference:** follow `docs/sync-api.md`. Push only settings with `synced = true`, as `setting` records `{id: key, value, updatedAt, deleted, updatedByDevice}`. Handle `410 resync_required` by pulling from 0 and dropping local synced records the server doesn't have. Push in batches of at most 500. Devices come from `GET /devices` (revoked = `deleted: true`), not from sync. Device ids are compared as strings to break `updatedAt` ties, so use the same id the device logged in with. The account setup page calls `POST /auth/setup` (needs the setup secret).
- **Server (later):** backups are stored in the same Turso database; an off-site copy (e.g. a GitHub Actions job downloading one) could be added. On a self-hosted server without a proxy, `X-Forwarded-For` can be spoofed, so only the per-username login limit is reliable there.
- **M6:** every table has `id` (UUID v7), `updatedAt` (UTC ms), `deleted`, `updatedByDevice`. `settings.synced` marks shared keys (only `week_start` so far). `task_target_devices` exists for "Notify on devices". Tombstoned tasks keep their subtasks and tag links (needed for undo), and the server's 90-day purge should remove the children too. The device name is pre-filled ("Fedora Laptop") and becomes editable in M6.
- **M7 (later):** time windows / days for location reminders and a one-shot option are not built (SPEC 3.3 "nice to have"). A repeating task's next copy is open at once, so its location reminder is active before its due date. No sync on geofence wake-ups (location events don't need it). Location notifications from the native side only exist on iOS; desktop never fires them. The Linux/Windows map needs internet for tiles and search.
- **M7, Riverpod 3:** providers nobody listens to are paused, so code outside the widget tree (background sync, tests) must `container.listen` a provider before awaiting it.
- **M7, iOS:** the background engine registers all plugins plus `LocationRemindersPlugin` (`AppDelegate.swift`). With UIScene, workmanager's launch handlers must be registered in `didFinishLaunching` (done). The database uses drift's `shareAcrossIsolates`, so the background engine talks to the app's database isolate when the app is alive.
- **M8:** JSON export/import can reuse the shared models' `toJson`/`fromJson`. New screens (export/import, logs) go in `app/lib/ui/shared/` so they're built once for all designs. Long words in the phone week view are cut with "…" (`WholeWordsText`), never split.
- **Testing tip:** in widget tests, drift query streams wait on the fake test clock. Read the database with plain queries inside `tester.runAsync`, and unmount the app at the end of each test (see `appTest` in `app/test/widget/app_test.dart`).
