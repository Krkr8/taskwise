# Taskwise — Project Specification

> Working name: **Taskwise** (rename freely). This file is the single source of truth for Claude Code.
> Work **one milestone at a time**. Do not start the next milestone until the current one is done, tested, committed, and the **Progress Log** at the bottom is updated.

---

## 0. Rules for Claude Code (read first, every session)

1. Read this whole file before doing anything. Then read the **Progress Log** to see which milestone is next.
2. Work only on the **current milestone**. If you notice something that belongs to a later milestone, write it under "Notes for later" in the Progress Log instead of doing it.
3. Start each milestone in plan mode: propose a short plan (files, packages, steps), wait for the owner's approval, then build.
4. Before adding any package, check it is maintained and supports the platforms it's needed on (Windows, Linux, iOS). Pin versions. Prefer fewer dependencies.
5. Verify current facts (package APIs, GitHub Actions runner names, iOS APIs, SideStore/AltStore status) from official docs instead of relying on memory.
6. Write tests for logic (data model, recurrence, sync, reminder scheduling). Run them before finishing a milestone.
7. At the end of each milestone:
   - Run `flutter analyze`, the tests, and a Linux build (`flutter run -d linux`) when relevant.
   - Commit with message `M<n>: <title>` and push.
   - Update the Progress Log: what was done, how to test it, known issues.
   - Tell the owner exactly what to do to test it on their devices (step by step, beginner-friendly commands).
8. Never hardcode secrets, IPs, or personal data. Config goes in settings or a config file listed in `.gitignore`.
9. The repo may become public open source later: keep code clean, documented, and licensed (MIT unless the owner says otherwise).
10. The owner develops on **Fedora 44 (GNOME)** using Claude Code in the terminal. Commands you give must work there. Windows and iOS builds happen through GitHub Actions (and optionally on the Windows PC).

---

## 1. What we're building

A personal, self-hosted **to-do + reminders app** that runs on:

| Device | OS | Role |
|---|---|---|
| Desktop PC | Windows 11 | App. |
| Laptop | Fedora 44, GNOME (Wayland) | App. Development machine. |
| Phone | iOS 27 (iPhone) | App. **Only device that does location reminders.** |
| Cloud | Vercel (free Hobby plan) + hosted database | Sync server. Public HTTPS, reachable from anywhere. Nothing for the owner to maintain. |

Single user (the owner). One device used at a time, so conflicts are rare. Designed so it could later be published as an open-source self-hosted app (multiple users not required now, but don't make it impossible).

### Owner has NO Mac
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
- **Server (sync server):** TypeScript with **Hono**, deployed as **Vercel Functions** on the free Hobby plan. The owner can't maintain or secure a Linux server, so the server must be fully managed.
  - Storage: a hosted database, because Vercel has no persistent disk. Prefer **Turso** (SQLite-compatible), with **Neon** (Postgres) as the alternative. Avoid Supabase's free tier (it pauses inactive projects).
  - Public **HTTPS** on the free `*.vercel.app` address (custom domain optional). No VPN app needed on any device.
  - Scheduled jobs (tombstone purge, daily backup export) run as a **Vercel Cron** job, because serverless functions have no background process.
  - Hono is portable: the same code must also run as a plain Node server with a Dockerfile, for future open-source self-hosters.
  - The server does not reuse the Dart `shared` package. It only stores and serves records; recurrence and reminder logic stay in the app. To keep the Dart app and the TypeScript server in agreement, the sync API is defined once in `docs/sync-api.md`, with JSON fixture files in `shared/test/fixtures/` that both the Dart and the TypeScript tests load.
  - At the start of M5, verify the current free limits of Vercel Hobby (function invocations, cron frequency) and the chosen database.
- **CI/CD:** GitHub Actions: tests (Dart and TypeScript), Linux build, Windows build, unsigned iOS .ipa. Artifacts attached to GitHub Releases. Vercel deploys the server.
  - Note: macOS runners consume more minutes on private repos; public repos are free. Check current GitHub pricing and tell the owner.

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
  - Completing a repeating task (owner's choice, 2026-10-30): the ticked task stays in Completed as history (without the rule), and a new copy appears on the next occurrence that is today or later, with the same content, tags and rule, and its subtasks unticked. Undo removes the copy. Changing the due date re-anchors the rule.
- **Reminders** (0 or more per task, see 3.3)
- **Notify on devices:** a set of registered devices. **Default = all devices.**
- Created/updated timestamps, soft-delete (tombstone) for sync

### 3.2 Views
- **List view:** groups: Overdue, Today, Tomorrow, This week, Later, No date, Completed (collapsible). Filter by category, priority, tag; search by text; sort options.
- **Weekly calendar view:** 7 columns, week starts on the day chosen in settings (**default Sunday**). Timed tasks placed at their time, all-day tasks in a top row. Swipe/arrow to previous/next week, "Today" button. Tap a day to add a task on that day. Drag a task to another day/time (desktop) — nice to have.
  - Same layout on every platform, phone included (owner's choice, 2026-10-30): header "Month Year · This week" and today's column outlined in the accent colour. **No hour timeline** (changed at the owner's request, 2026-10-30): each day column is a list of its tasks, all-day tasks first, then timed ones in time order, each chip showing its time above the title. Tap a day header or the empty part of a column to add a task that day. Upcoming repeats show faded.
- **Monthly calendar view** (added in M3 at the owner's request, all platforms): 6-week grid from the week-start day; task chips per day (coloured dots on narrow screens) with "+N"; tapping a day opens its agenda (side panel on wide screens, bottom sheet on phones). The Calendar tab switches between week and month.
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

### 3.4 Account & devices
- One account (username + password) on the server, created once with `POST /auth/setup` (setup page in the app). The server is public, so setup requires a long random **setup secret** set as a Vercel environment variable; without it, anyone could claim the account first. Setup is refused once an account exists.
- Each app install = a **device**. On first launch: enter server address, log in, give the device a name (pre-filled: "Windows PC", "Fedora Laptop", "iPhone"), device type is detected.
  - Changed in M6 (owner's choice, 2026-11-02): **signing in is optional**. The app opens straight to the tasks; a one-time banner and **Settings → Sync → Connect to your server** open the sign-in screen (server address, username, password, device name; a "First time? Create the account" link adds the setup secret and calls `/auth/setup`). Data already on a device is uploaded and merged when it first connects. Signing out revokes the device and keeps local data.
  - **Main device** (owner's request, 2026-11-02): the first device to sign in is the main device and manages the account's devices. Only it can remove or rename other devices and pass the role on (Settings → Sync → Devices → ⋯ → Make main device). Any device can rename itself and sign out. If the main device signs out or is removed, the most recently seen device takes over; if it is lost, any device can take the role with the account password ("Make this the main device"). Server rules in `docs/sync-api.md`.
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
  - **iOS background refresh is deferred to M7** (owner's choice): the iPhone syncs while Taskwise is open.
- API: JSON over HTTPS, versioned (`/api/v1/...`), token auth in header. Endpoints at minimum: `POST /auth/login`, `POST /auth/setup`, `GET/POST /sync`, `GET/PATCH/DELETE /devices`, `GET /health`. Documented in `docs/sync-api.md`, with JSON fixtures in `shared/test/fixtures/` tested on both sides.
- The server is public on the internet (Vercel always serves HTTPS). Every endpoint except `/health`, `/auth/login` and `/auth/setup` requires a valid device token.
- Server backups: the database provider's own backups, plus a daily cron export of all records, keeping the last N. Each device also holds a full copy of the data (local-first), and JSON export is available.

---

## 5. Milestones

Each milestone ends with: tests passing, commit + push, Progress Log updated, and test instructions given to the owner.

### M0 — Project setup
- Check/install tools on Fedora: Flutter SDK (Linux desktop deps: clang, cmake, ninja, gtk3-devel, etc.), Git, GitHub CLI. Give the owner exact `dnf` commands; don't run `sudo` commands without asking.
- Create repo structure (`app`, `server`, `shared`, `docs`), license, README, `.gitignore`, analysis options, formatting.
- Basic GitHub Actions: analyze + tests on every push.
- **Done when:** `flutter run -d linux` shows a placeholder home screen; CI is green.

### M1 — Core app (local only)
- Data model + drift DB in `shared`/`app` (tasks, subtasks, categories, tags, reminders, places, devices, settings) with migrations.
- List view, quick add, task detail/edit, complete/uncomplete, delete (with undo snackbar), subtasks, priority, categories, search & filters.
- Settings: theme (light/dark/system), language EN/AR with RTL, week start, time format.
- Design system: colors, typography, spacing, hover animations, responsive layout.
- **Done when:** owner can fully manage tasks on Fedora, in both languages and themes; unit tests for model logic.

### M2 — Build pipeline for all platforms (de-risk iOS early)
- GitHub Actions: build Windows (.zip or MSIX/installer), Linux (tar.gz; AppImage or RPM nice to have), and **unsigned iOS .ipa** on a macOS runner. Upload as artifacts / release on tag.
- Configure iOS project: bundle ID, display name, icon placeholder, Info.plist permissions, background modes.
- Write `docs/install-ios-sidestore.md` (step-by-step for a beginner, Windows or Linux based), `docs/install-windows.md`, `docs/install-linux.md`.
- Confirm (and write down) which capabilities work with a free Apple ID.
- **Done when:** the owner has the M1 app running on Windows PC, Fedora laptop, and iPhone.

### M3 — Weekly calendar view + recurrence
- Weekly view per 3.2 (respects week-start setting and RTL).
- Monthly view per 3.2 (added 2026-10-30 at the owner's request).
- Recurrence rules per 3.1, with editor UI and solid tests (DST, month ends, leap years, "2nd Tuesday", timezone Asia/Baghdad and others).
- **Done when:** repeating tasks show correctly in list and week view on all devices.

### M4 — Time reminders & notifications
- Time reminders (absolute + relative, multiple per task), scheduling engine in `shared` (pure, tested), platform notification layer.
- Notification actions Done / Snooze where supported; tapping a notification opens the task.
- iOS 64-pending limit handling; reschedule on app start and data change.
- Windows: notifications even when the window is closed → minimize to system tray + start on login option. Linux (GNOME): same, with a background/autostart option (document GNOME tray limitations; use a background mode if no tray).
- **Done when:** reminders fire reliably on all three devices (owner tests with a list you provide).

### M5 — Sync server
- First, verify the current free limits of Vercel Hobby and the database (Turso preferred, Neon as fallback), and tell the owner.
- Replace the Dart placeholder in `server/` with a TypeScript + Hono server per sections 2 and 4: setup (with setup secret), login with rate limiting, devices, sync endpoints, hosted database with migrations, logging, Vercel Cron job (tombstone purge, daily backup export). Configuration only through environment variables (database URL and token, setup secret); never commit secrets.
- Write `docs/sync-api.md` and the shared JSON fixtures in `shared/test/fixtures/`; contract tests on both sides (Dart and TypeScript) load the same fixtures.
- Integration tests for the sync protocol against a local SQLite/libSQL database.
- The same server code also runs as a plain Node server with a Dockerfile (for self-hosters).
- CI: add a Node job that type-checks and tests the server.
- `docs/server-setup-vercel.md`: beginner steps from Fedora (create Vercel and database accounts, install the `vercel` CLI, set environment variables, deploy, find the server address).
- **Done when:** the server is deployed on Vercel and `GET /api/v1/health` works over HTTPS from the laptop and from the iPhone on mobile data.

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
- Give the owner a real-world test plan (walk away from/to home, etc.) and a debug screen showing monitored regions and last events.
- **Done when:** arrive and leave reminders fire on the iPhone at ~30 m, with the app closed.

### M8 — Design, polish & open-source readiness
- **Start by asking the owner for their design idea** (they asked for a design milestone on 2026-10-30 and have an idea ready). Plan the redesign with them before anything else in this milestone.
- Animation polish, empty states, onboarding hints, app icon, accent colors.
- JSON export/import, error handling, logs viewer.
- Performance check (1,000+ tasks).
- README with screenshots, CONTRIBUTING, self-hosting guide, versioned GitHub Releases.
- **Done when:** owner signs off.

---

## 6. Owner's preferences (summary)
- Single user now; maybe public open-source self-hosted later.
- Sync server hosted free on Vercel, reachable from anywhere over HTTPS; the owner doesn't maintain or secure servers. No server on the Windows PC.
- Location reminders only on iPhone; default radius 30 m; arrive/leave selectable.
- Week starts Sunday by default, changeable in settings.
- English + Arabic, switchable in settings.
- Notifications on all devices by default, selectable per task.
- Simple design, light/dark mode, subtle hover animations.
- Owner is comfortable with the terminal but not a mobile developer — explain device-side steps clearly.

---

## 7. Progress Log

### Where we left off (2026-11-05)
- **Status for a new chat:** The owner confirmed **v0.3.1 works** on all devices (2026-11-05). Their only request: the Undo snackbar never went away. Flutter keeps a snackbar with an action until it is dismissed, so Undo snackbars now set `persist: false` and fade after 5 seconds (`app/lib/ui/tasks/task_actions.dart`). Released as **v0.3.2** (draft release; files in `~/Downloads/taskwise-0.3.2/`). **Next: M7 in plan mode.**
- **M6 is closed (2026-11-03).** The owner tested v0.3.0 (sync connected on Fedora, Windows and iPhone) and reported four things, all done in **v0.3.1**:
  1. **Settings didn't scroll on Windows.** Mouse wheel and touchpad scrolling worked in tests, so the likely cause is scrolling by dragging, which Flutter turns off for the mouse on desktop. Mouse dragging is now allowed and scrollbars stay visible on desktop (`AppScrollBehavior` in `app/lib/app.dart`). **Confirm on Windows**, and ask how the owner scrolls if it still fails.
  2. **Tray → Quit didn't quit on Windows.** Quit now runs after the tray menu closes, every step is best-effort with a timeout, and the process always exits (`DesktopShell.quit`). **Confirm on Windows.**
  3. **Notifications stopped after connecting.**
     - Found a real iPhone bug: the iOS notifier removed entries from a map while looping over it, so rescheduling threw whenever a pending notification changed (common with sync). Fixed in `ios_notifier.dart`.
     - The owner's test reminder on the iPhone was for 11:12 **AM** on a task added at 23:10, already in the past. Reminders that can't fire any more now show "time passed".
     - Added **Settings → Notifications → Send a test notification** to check each device.
     - Windows notifications were never seen working (M4 was never tested there). **Check them on Windows with the test button first.**
  4. **A main device** that manages the account's devices (see 3.4). Server migration 2 makes the oldest active device main, which is the Fedora laptop.
- **Next:** **M7 (location reminders, iPhone)**, starting in plan mode. M7 also adds iOS background refresh for sync (deferred from M6).
- **Server:** the Vercel project `taskwise` (Root Directory `server`, function region `fra1`, Node 24) with the Turso database `taskwise` (`aws-eu-central-1`). Pushes to `main` deploy automatically. The server address and secrets are in the owner's `~/.config/taskwise/server-secrets.env` (never in the repo). The account exists (created from Fedora on 2026-11-02). The owner was asked to delete the Vercel token (pasted in chat) at vercel.com/account/tokens and from that file.
- **Release files:** the release workflow builds drafts; Claude Code downloads them for the owner with `gh release download v<version> --dir ~/Downloads/taskwise-<version>`. The owner copies the Windows zip to the PC (or downloads it from the draft release while signed in to GitHub), and installs the .ipa with iloader → Import IPA.
- **iPhone install:** with iloader from the laptop (SideStore sign-in is broken by Apple since 2026-10-12, error -80045). Refresh every 7 days with iloader → Import IPA. See `docs/install-ios-sidestore.md`.
- **M8 starts by asking the owner for their design idea** (they asked for a design milestone; merged into M8).
- Running app tests on the Fedora laptop: take ccache off `PATH` (see `docs/dev-setup-fedora.md`), and re-run if a file fails with "Unable to connect to flutter_tester process" (or use `--concurrency=1`). The live sync test needs a local server: see the comment at the top of `app/test/sync/live_server_test.dart`.

| Milestone | Status | Date | Notes |
|---|---|---|---|
| M0 Project setup | ✅ Done | 2026-10-20 | Flutter 3.47.7 workspace (app/server/shared), placeholder screen, CI green. |
| M1 Core app | ✅ Done | 2026-10-20 | Local-only task manager: drift DB, list/quick add/details, subtasks, categories, tags, search/filter/sort, EN/AR with RTL, light/dark. 67 automated tests. Owner-tested on Fedora. |
| M2 Build pipeline | ✅ Done | 2026-10-30 | Release workflow builds Linux, Windows and unsigned iOS into a draft v0.1.0 release. Owner-tested on Fedora, Windows and iPhone. The iPhone app is installed with iloader from the laptop, because Apple blocks SideStore's own sign-in (-80045) since 2026-10-12. Also fixed from iPhone testing: tapping outside a text field (or scrolling) closes the keyboard, and selected Settings options use the accent colour. 69 automated tests. |
| M3 Calendar + recurrence | ✅ Done | 2026-10-30 | Calendar tab with week (7 day columns listing tasks, all-day first then by time) and month views on all platforms; repeating tasks (RRULE subset in `shared`, editor with presets and Custom, done copy + next occurrence with Undo); upcoming repeats shown faded in the calendar. Selected chips now clearly highlighted. 115 automated tests (shared tests run in 3 timezones in CI). |
| M4 Time reminders | ✅ Done | 2026-10-31 | Time reminders (relative + absolute, several per task, follow repeats), scheduling engine in `shared`, notifications with Done/Snooze/open, iOS 64-limit scheduling, desktop tray + single instance + start on login, notification settings. A real reminder fired on Fedora (GNOME) with Done/Snooze buttons. Closed by the owner on 2026-10-31 before device tests: **Windows and iPhone are untested** (see Where we left off). 138 automated tests. |
| M5 Sync server | ✅ Done | 2026-11-02 | TypeScript + Hono server in `server/` (Node 24): account setup with a setup secret, login (argon2id) with database-backed rate limiting, per-device tokens (SHA-256 stored, revocable), devices API, push/pull sync with last-write-wins and a change sequence, daily Vercel Cron (90-day tombstone purge with task children, 7 nightly backups in the database). Generic record store: the server doesn't interpret records. API in `docs/sync-api.md`; contract fixtures in `shared/test/fixtures/sync/` tested by both Dart and TypeScript. Runs on Vercel or Docker (built and run with Podman locally). Dart `server/` placeholder removed; CI has a Node job. Free limits checked 2026-10-31 (Vercel Hobby: 1 M invocations/month, cron daily; Turso Free: 5 GB, 500 M reads, 10 M writes). 228 automated tests (app 53, shared 106, server 69). Deployed on Vercel (`fra1`) with Turso (`aws-eu-central-1`); health checked over HTTPS from the laptop and from the iPhone on mobile data. |
| M6 Client sync + devices | ✅ Done | 2026-11-03 | Optional sign-in from Settings (with account setup), one-time banner, sync engine (trigger-filled outbox, push/pull with last-write-wins, full resync on 410, device list), sync triggers (start, resume, 2 s after changes, every minute, Sync now), status icon, Settings → Sync and → Devices, sign out, "Notify on" per task with each device scheduling only its own reminders. Owner-tested v0.3.0: sync connects on Fedora, Windows and iPhone. Closed with the v0.3.1 fixes (Windows scrolling and tray Quit, iOS rescheduling bug, test-notification button, "time passed" reminders) and the **main device** (manages the other devices). Database schema v3. Live test: two app devices through the real TypeScript server (also in CI). 276 automated tests (app 85 incl. 1 live, shared 112, server 79). v0.3.1 confirmed by the owner on all devices (2026-11-05); v0.3.2 makes the Undo snackbar fade after 5 s. |
| M7 Location reminders | ⬜ | | |
| M8 Design + polish | ⬜ | | |

### How to test the latest milestone
**v0.3.2 (Undo fades away).** Install v0.3.2 as before. Delete a task, or complete a repeating one: the "Undo" bar at the bottom disappears by itself after about 5 seconds.

**v0.3.1 (M6 fixes and the main device).** Install v0.3.1 on Windows and the iPhone (files in `~/Downloads/taskwise-0.3.1/` on the laptop). Fedora: `git pull`, then `cd app && flutter run -d linux`. Quit Taskwise first everywhere (tray → Quit). Your sign-in and tasks are kept.

1. **Windows, Settings:** scroll with the mouse wheel, by dragging with the mouse, and with the scrollbar on the right.
2. **Windows, tray:** right-click the tray icon → **Quit Taskwise**. Taskwise closes completely, and its icon disappears from the tray.
3. **Every device:** **Settings → Notifications → Send a test notification**. A Taskwise notification appears. If not:
   - Windows: Settings → System → Notifications (Taskwise on, Do not disturb off).
   - iPhone: Settings → Notifications → Taskwise.
4. **Reminder on each device:** a task due in 5 minutes (check AM/PM) with **At due time**. It reminds you. A reminder whose time is already over shows "time passed".
5. **Main device:** Settings → Sync → Devices on Fedora shows "Main device · This device", and the ⋯ menu of the other devices has **Remove** and **Make main device**. On the iPhone, other devices have no ⋯ menu, and there is a **Make this the main device** button (asks for your password).

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
7. **Offline:** turn the laptop's Wi-Fi off, edit a task (the cloud icon shows offline), turn it on: the change arrives on the other devices.
8. **Sign out** on one device (Settings → Sync): its tasks stay; it no longer syncs, and it is gone from the Devices list on the others.

Also run the **M4 list below on Windows and the iPhone** with this build (reminders were never tested there).

**M5 (sync server).** Follow `docs/server-setup-vercel.md` step by step. In short:
1. `git pull`. Make the setup and cron secrets (step 1) and keep them in your password manager.
2. Create the Turso database and copy its URL and token (step 2).
3. Import the repo in Vercel with **Root Directory = `server`**, add the four environment variables, deploy, and set the function region near the database (step 3).
4. From the laptop, run `curl https://<your-app>.vercel.app/api/v1/health`. It should print `{"status":"ok","apiVersion":1,…}`.
5. On the iPhone, turn Wi-Fi off and open the same address in Safari. You should see the same text.
6. Optional: create your account with the `curl` in step 5 of the guide. A second try should say "The account already exists".
7. Tell Claude Code the result (and the error text or Vercel **Logs** if something fails).

Local checks (optional): `cd server && npm ci && npm test`. To run the server on the laptop: `cp .env.example .env && npm run dev`, then `curl http://localhost:8787/api/v1/health`.

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
- **Please review the Arabic text** (`app/lib/l10n/app_ar.arb`). Claude Code wrote the translations, and a native speaker should check them (M3 added the repeat and calendar texts, including Arabic plural forms).
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
- **Local test runner:** `flutter test` sometimes fails to start one test file with "Unable to connect to flutter_tester process" on the Fedora laptop. It's the runner, not the code; re-run, or use `flutter test --concurrency=1`.
- **Reminders (later):** Done/Snooze on iOS open the app; handling them in the background needs a background isolate with its own database connection. iOS snooze buttons are registered at launch, so changed snooze options apply on iOS after restarting the app. Windows `cancel` of shown toasts needs MSIX packaging. The first iPhone/Windows builds with `tray_manager` (which builds `cnativeapi` native code, iOS included) are untested; check the v0.2.0 release run.
- **M6:** after a sync pull, the reminder scheduler re-plans automatically (it watches the tasks and reminders streams). The default reminder setting is marked synced.
- **Vercel entry file:** Vercel uses the first file among `app.ts`, `index.ts`, `server.ts`, `src/app.ts`, `src/index.ts`, `src/server.ts` that imports `hono` itself. So the app factory lives in `src/api.ts` (not `app.ts`), and `src/index.ts` keeps a value `import { Hono } from 'hono'`. Both mistakes broke the first deploys (FUNCTION_INVOCATION_FAILED, then "No entrypoint found which imports hono").
- **M5 versions:** TypeScript is pinned to 6.0.3, because 7.0 (the new native compiler) was released on 2026-10-31 itself; move to 7.x once it has settled. `npm install` warns that esbuild's postinstall script (used only by the `tsx` dev runner) isn't approved; it works without it.
- **Sync (later):** `flutter_secure_storage` is pinned to 10.0.0 because 11.x needs `win32` 6, while `launch_at_startup` 0.5.1 (start on login) still needs `win32` 5. Move up when `launch_at_startup` does. When two devices had categories or tags with the same name before connecting, both copies are kept (merge them by hand). Signing in to a different server re-uploads everything.
- **M7:** add iOS background refresh for sync here (deferred from M6), together with the geofence wake-ups.
- **Account (later):** changing the account password isn't possible yet (only by resetting the database). The main device would be the natural place for it.
- **Done in M6, for reference:** follow `docs/sync-api.md`. Push only settings with `synced = true`, as `setting` records `{id: key, value, updatedAt, deleted, updatedByDevice}`. Handle `410 resync_required` by pulling from 0 and dropping local synced records the server doesn't have. Push in batches of at most 500. Devices come from `GET /devices` (revoked = `deleted: true`), not from sync. Device ids are compared as strings to break `updatedAt` ties, so use the same id the device logged in with. The account setup page calls `POST /auth/setup` (needs the setup secret).
- **Server (later):** backups are stored in the same Turso database; an off-site copy (e.g. a GitHub Actions job downloading one) could be added. On a self-hosted server without a proxy, `X-Forwarded-For` can be spoofed, so only the per-username login limit is reliable there.
- **M6:** every table has `id` (UUID v7), `updatedAt` (UTC ms), `deleted`, `updatedByDevice`. `settings.synced` marks shared keys (only `week_start` so far). `task_target_devices` exists for "Notify on devices". Tombstoned tasks keep their subtasks and tag links (needed for undo), and the server's 90-day purge should remove the children too. The device name is pre-filled ("Fedora Laptop") and becomes editable in M6.
- **M7:** the `places` table and `Place` model exist (default radius 30 m).
- **M8:** JSON export/import can reuse the shared models' `toJson`/`fromJson`. An accent colour picker can hook into `AppTheme.seed`.
- **Testing tip:** in widget tests, drift query streams wait on the fake test clock. Read the database with plain queries inside `tester.runAsync`, and unmount the app at the end of each test (see `appTest` in `app/test/widget/app_test.dart`).
