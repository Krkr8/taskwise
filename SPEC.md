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
| Phone | iOS 27 (iPhone) | App. Location reminders fire on phones only. |
| Phone | Android 8.0+ (M10) | App (signed APK on GitHub Releases). Location reminders too. Tested on the emulator only. |
| Cloud | Vercel (free Hobby plan) + hosted database | Sync server. Public HTTPS, reachable from anywhere. Nothing to look after. |

Single user (the maintainer). One device used at a time, so conflicts are rare. Designed so it could later be published as an open-source self-hosted app (multiple users not required now, but don't make it impossible).

### No Mac
- iOS app is built in the cloud (GitHub Actions macOS runner) as an **unsigned .ipa**, then installed with **SideStore** (or AltStore) using a free Apple ID. Free-account signing expires every 7 days and must be refreshed (SideStore can refresh on-device). A paid Apple Developer account ($99/yr) removes that limit — optional, later.
- Because of free signing: **do not use Apple Push Notifications (APNs)**. All iPhone notifications are **local notifications** scheduled by the app itself. Sync happens when the app runs (open, background refresh, geofence wake).
- Only use iOS capabilities that work with free provisioning: background location, local notifications, background fetch. Verify this in M2.
- iOS-specific Swift code cannot be compiled locally. Keep native Swift code small, isolated, and well-commented; CI is the compiler.

---

## 2. Tech stack (decided)

- **App:** Flutter (Dart), one codebase for Windows, Linux, iOS, Android (M10).
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
- How M10 implements it on **Android** (2026-11-07): the same design in Kotlin, in a local plugin (`app/packages/taskwise_android`, so it is also registered in workmanager's background engine). `GeofenceEngine.kt` is a line-by-line port of the Swift `GeofenceEngine` (same numbers; `GeofenceEngineTest.kt` mirrors RunnerTests, `GeofenceWalkTest.kt` the walk simulator, all 8 walks 300/300). `LocationReminderManager.kt` uses Google Play services `GeofencingClient` (outer and near areas, up to 90; with more reminders a 2 km "re-pick" area around the phone re-picks the nearest) and a short foreground service (`PreciseLocationService`, type `location`, quiet "Checking your location…" notification) for the precise check. "Where am I now" for new areas comes from one fix (no initial trigger). State is saved in SharedPreferences after every event; `BootReceiver` re-adds geofences after a reboot or an app update. Notifications are posted natively in flutter_local_notifications' intent format (`SELECT_NOTIFICATION` + `notificationId`/`payload`/`actionId`), so Done/Snooze/tap reach Dart like time reminders; their buttons come from Dart (`actions` in each entry, ignored by iOS). Permission: "While using the app" (precise), then "Allow all the time" on Android's settings page. Needs Google Play services and **Location Accuracy** on (geofence error 1000 otherwise).

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

### 3.7 Assistants (M11)
- **Siri (iPhone)**, English and Arabic, without opening the app: "Add a task in Taskwise" (Siri asks for the title), "Add a task with a date in Taskwise" (then "When is it due?"; a day alone is all-day), "What's on my list in Taskwise" (today's and overdue tasks). Apple allows no free text inside the phrase and requires the app's name in it.
- How it works (maintainer's choice, 2026-11-12: add quietly, without opening the app): App Intents in `app/ios/Runner/AssistantIntents.swift`. Native code never writes the database. Siri appends to an **inbox** file (`AssistantStore.swift`, ids are UUID v7 and become the task ids); Dart moves the entries in through `TaskRepository.createTask` at start, on resume, when Siri adds while the app runs, and in the background sync (`app/lib/assistant/assistant_sync.dart`), adding the default reminder to timed ones. Dart writes a **snapshot** of open tasks due within 7 days plus overdue ones (`buildAssistantSnapshot` in shared); Siri filters it by its own "today".
- **Android:** a static "New task" shortcut (long-press the icon → quick add focused) and a share target (`ACTION_SEND text/plain`: first line or subject = title, the rest = notes, "Added …" with Open). `AssistantIntents.kt` in the local plugin; channel `taskwise/assistant`, same methods on both phones.
- **Gemini:** not possible yet (AppFunctions for Gemini is in a closed preview, Android 16+). See "Notes for later". User guide: `docs/assistants.md`.

### 3.8 Updates inside the app (M12)
- Maintainer's choices (2026-11-12): **ask, then install** (daily check, banner, one tap), **signed updates**, one commit for M11 + M12 released as 1.1.0 (the last manual install).
- Check: `GET api.github.com/repos/Krkr8/taskwise/releases/latest` (published releases only) at start + 15 s and when 20 h have passed, if "Check for updates automatically" is on (device setting); Settings → About → Check for updates. Versions compared as semver (`AppVersion` in shared).
- Safety: the release workflow writes `SHA256SUMS` and an Ed25519 `SHA256SUMS.sig` (`tool/sign_release.sh`, secret `UPDATE_SIGNING_KEY`, checked against the app's key); the app verifies the signature with the built-in public key (`app/lib/update/update_key.dart`, package `cryptography`), then the file's SHA-256, before installing. A verified download is kept for a retry (Android permission, Cancel).
- Install (`app/lib/update/update_installer.dart`): Windows: a PowerShell helper (robocopy, no deletes) after Taskwise quits; Linux AppImage: rename over `$APPIMAGE`; Linux tar.gz: swap `~/.local/share/taskwise`; both restart through a detached `sh` that waits for the old process (single instance). Android: `PackageInstaller` session (`AppUpdater.kt`, `REQUEST_INSTALL_PACKAGES`). iPhone and source builds: notice + release page (`url_launcher`). Each release also has `sidestore-source.json` for SideStore. Guide: `docs/updates.md`.

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
  - **Android (M10):** the same `workmanager` task runs about every 30 minutes with a network (`ExistingPeriodicWorkPolicy.update`).
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

### M11 — Siri and Android shortcuts
- Asked for by the maintainer on 2026-11-12: talk to Taskwise through a phone assistant. Research: Siri works through App Intents (no entitlement, so it should work with free signing; to be confirmed on the iPhone); Gemini can't call third-party apps yet. Scope chosen: Siri (add, add with a date, what's due; EN + AR) and on Android the "New task" shortcut and "Share to Taskwise". Details in 3.7.
- **Done when:** the tests pass (shared, app, Swift on Linux, Kotlin), the Android shortcut and share work on the emulator, and Siri adds and reads tasks on the maintainer's iPhone.

### M12 — In-app updates
- Asked for by the maintainer on 2026-11-12: install updates from inside the app on every platform. Possible on Windows, Linux and Android; the iPhone gets a notice (iOS apps can't install apps) and a SideStore source. Details in 3.8.
- **Done when:** tests pass (signature, tampering, Linux installers on real files), a real update works on the Android emulator, the 1.1.0 release is signed by the workflow, and later the maintainer updates Windows and Linux from 1.1.0 to the next version with one tap.

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

### Where we left off (2026-11-14)
- **Status for a new chat:** **M11 (Siri and Android shortcuts) and M12 (in-app updates) are released as v1.1.0** (commit `M11 + M12: Siri, Android shortcuts and in-app updates`, published 2026-11-14; the release has `SHA256SUMS`, `SHA256SUMS.sig` and `sidestore-source.json`, and the signature was checked against the app's key). The SPEC.md privacy cleanup went in the same commit (the "How to test" walkthroughs and the server regions were removed from this public file; they stay in git history, and the maintainer chose not to rewrite it). The GitHub secret `UPDATE_SIGNING_KEY` is set. Next: the maintainer installs 1.1.0 by hand on every device (the last manual install; the Linux machine uses the tar.gz with `install.sh`), tests Siri on the iPhone, and the next release (1.1.1 or 1.2.0) is the first real in-app update, including the first Windows test. The iPhone guide now has **Way 1: iloader only** first and Way 2: SideStore second. The 1.0.0 test results (tray menu, M9 and M10 checks) are still to be confirmed.
- **Siri is unconfirmed on a free-signed install.** App Intents need no entitlement, so they should work, but nobody has reported it for sideloaded apps. If Siri doesn't see the commands after the steps in `docs/assistants.md`, check the release build log for "Extract App Intents Metadata" and whether iloader's re-signing keeps `Metadata.appintents` in the app bundle.
- **Android toolchain on the Linux machine:** Android builds need a full JDK 21: Eclipse Temurin 21 in `~/.local/jdk-21` (Fedora 45 has no JDK 21 package), set with `flutter config --jdk-dir`. Gradle on its own needs `JAVA_HOME=$HOME/.local/jdk-21` (the system has only a Java 25 runtime). `flutter config --enable-android` is on. The emulator is `Pixel_9_API_36` (google_apis, x86_64).
- **The repo is public** (2026-11-07). It was recreated on GitHub with a clean history: every commit is by `Krkr8` with the GitHub noreply email, and LICENSE says Krkr8. Don't put the maintainer's name, email or server address anywhere (commits, docs, the repo's homepage field). The docs say "the maintainer" and name no devices or server details. v0.6.0 is published (the earlier drafts were lost with the old repo). Vercel's GitHub app has access to the new repo, and pushes to `main` deploy again.
- v0.3.1 was confirmed on all devices (2026-11-05); v0.3.2 made the Undo bar fade after 5 seconds.
- **Things to watch in the M7 device test** (all untestable without the phone):
  - Region events with the app swiped away (iOS relaunches it in the background; `LocationReminderManager` starts in `AppDelegate`).
  - Precise updates started from the background need "Always" location access.
  - "Leave" fires after iOS reports leaving the ~100 m outer region (plus iOS's delay, often 20 s to 3 min), so usually 150-400 m from home on foot. The maintainer should know this; continuous tracking at home would drain the battery.
  - Background sync: iOS decides when it runs (rarely for a sideloaded app that's seldom opened). Settings → Sync's "Synced …" time shows whether it ran.
- **Server:** deployed on Vercel (Root Directory `server`, Node 24) with a Turso database. Pushes to `main` deploy automatically. The server address and secrets are only in the maintainer's `~/.config/taskwise/server-secrets.env` (never in the repo). The account exists.
- **Release files:** the release workflow builds drafts; Claude Code downloads them for the maintainer with `gh release download v<version> --dir ~/Downloads/taskwise-<version>`. The maintainer copies the Windows zip to the Windows machine (or downloads it from the draft release while signed in to GitHub), and installs the .ipa with iloader → Import IPA.
- **iPhone install:** with iloader only from the Linux machine (Way 1 in `docs/install-ios-sidestore.md`; SideStore sign-in is broken by Apple since 2026-10-12, error -80045). Refresh every 7 days with iloader → Import IPA.
- Running app tests on the Linux machine: take ccache off `PATH` (see `docs/dev-setup-fedora.md`), and re-run if a file fails with "Unable to connect to flutter_tester process" (or use `--concurrency=1`). The live sync test needs a local server: see the comment at the top of `app/test/sync/live_server_test.dart`.

| Milestone | Status | Date | Notes |
|---|---|---|---|
| M0 Project setup | ✅ Done | 2026-10-20 | Flutter 3.47.7 workspace (app/server/shared), placeholder screen, CI green. |
| M1 Core app | ✅ Done | 2026-10-20 | Local-only task manager: drift DB, list/quick add/details, subtasks, categories, tags, search/filter/sort, EN/AR with RTL, light/dark. 67 automated tests. Maintainer-tested on Fedora. |
| M2 Build pipeline | ✅ Done | 2026-10-30 | Release workflow builds Linux, Windows and unsigned iOS into a draft v0.1.0 release. Maintainer-tested on Fedora, Windows and iPhone. The iPhone app is installed with iloader from the Linux machine, because Apple blocks SideStore's own sign-in (-80045) since 2026-10-12. Also fixed from iPhone testing: tapping outside a text field (or scrolling) closes the keyboard, and selected Settings options use the accent colour. 69 automated tests. |
| M3 Calendar + recurrence | ✅ Done | 2026-10-30 | Calendar tab with week (7 day columns listing tasks, all-day first then by time) and month views on all platforms; repeating tasks (RRULE subset in `shared`, editor with presets and Custom, done copy + next occurrence with Undo); upcoming repeats shown faded in the calendar. Selected chips now clearly highlighted. 115 automated tests (shared tests run in 3 timezones in CI). |
| M4 Time reminders | ✅ Done | 2026-10-31 | Time reminders (relative + absolute, several per task, follow repeats), scheduling engine in `shared`, notifications with Done/Snooze/open, iOS 64-limit scheduling, desktop tray + single instance + start on login, notification settings. A real reminder fired on Fedora (GNOME) with Done/Snooze buttons. Closed by the maintainer on 2026-10-31 before device tests: **Windows and iPhone are untested** (see Where we left off). 138 automated tests. |
| M5 Sync server | ✅ Done | 2026-11-02 | TypeScript + Hono server in `server/` (Node 24): account setup with a setup secret, login (argon2id) with database-backed rate limiting, per-device tokens (SHA-256 stored, revocable), devices API, push/pull sync with last-write-wins and a change sequence, daily Vercel Cron (90-day tombstone purge with task children, 7 nightly backups in the database). Generic record store: the server doesn't interpret records. API in `docs/sync-api.md`; contract fixtures in `shared/test/fixtures/sync/` tested by both Dart and TypeScript. Runs on Vercel or Docker (built and run with Podman locally). Dart `server/` placeholder removed; CI has a Node job. Free limits checked 2026-10-31 (Vercel Hobby: 1 M invocations/month, cron daily; Turso Free: 5 GB, 500 M reads, 10 M writes). 228 automated tests (app 53, shared 106, server 69). Deployed on Vercel with Turso; health checked over HTTPS from the Linux machine and from the iPhone on mobile data. |
| M6 Client sync + devices | ✅ Done | 2026-11-03 | Optional sign-in from Settings (with account setup), one-time banner, sync engine (trigger-filled outbox, push/pull with last-write-wins, full resync on 410, device list), sync triggers (start, resume, 2 s after changes, every minute, Sync now), status icon, Settings → Sync and → Devices, sign out, "Notify on" per task with each device scheduling only its own reminders. Maintainer-tested v0.3.0: sync connects on Fedora, Windows and iPhone. Closed with the v0.3.1 fixes (Windows scrolling and tray Quit, iOS rescheduling bug, test-notification button, "time passed" reminders) and the **main device** (manages the other devices). Database schema v3. Live test: two app devices through the real TypeScript server (also in CI). 276 automated tests (app 85 incl. 1 live, shared 112, server 79). v0.3.1 confirmed by the maintainer on all devices (2026-11-05); v0.3.2 makes the Undo snackbar fade after 5 s. |
| M7 Location reminders | ✅ Done | 2026-11-06 | Map picker (flutter_map + OSM, Nominatim search behind a swappable `Geocoder`), saved places, location reminders on every device (Arrive / Leave, 30-500 m, fire every time, 30 min debounce), schema v4 (`reminders.label`). iPhone: native Swift geofencing (outer region + precise check, 20-region limit, debug screen), permission explanation and banner (EN/AR, Arabic `InfoPlist.strings`). iOS background refresh sync with `workmanager` 0.10.10; token readable after first unlock. New iOS CI workflow runs the Swift tests. 300 automated tests (app 102 + 1 live, shared 119, server 79) + 9 Swift tests. v0.4.1: `GeofenceEngine` + walk simulator, 3 geofencing bugs fixed, Linux integration test; 16 Swift tests. Closed by the maintainer without the iPhone walk test (skipped). |
| M8 Design + polish | ✅ Done | 2026-11-07 | Design tour screenshots; Opus/Gemini design contest; four designs selectable per device (Classic, Lapis, Slate & Indigo, Brutal default with warm charcoal dark mode); UI split into `ui/shared` + `ui/designs/<name>`; `docs/architecture.md`. v0.6.0: centred Settings, cloud button syncs, JSON backup export/import, logs viewer + error logging, 2,000-task performance test (Opus subagent) with lazy lists, README/CONTRIBUTING/self-hosting/CHANGELOG (Sonnet subagent), whole-word titles in the phone week view. 405 automated tests (app 207 + 1 live, shared 119, server 79) + 16 Swift tests; 3 Linux integration tests (location, design tour, performance). Signed off by the maintainer on 2026-11-07. |
| M9 Linux AppImage | ✅ Built (v0.6.1), maintainer test pending | 2026-11-07 | `taskwise-<v>-linux-x86_64.AppImage` next to the tar.gz, both built on Ubuntu 22.04. Bundles libsecret (RUNPATH fixed with patchelf, since plugins load it); pinned appimagetool and runtime. Start on login uses `$APPIMAGE`. Smoke test in podman: starts on Debian 12, Ubuntu 22.04, Ubuntu 24.04 and Arch; also run on Fedora with FUSE. Minimal Debian/Ubuntu installs need `libegl1 libgles2` (Flutter loads them; every desktop has them). 408 automated tests (app 210 + 1 live, shared 119, server 79). |
| M10 Android | ✅ Built (v0.7.0), emulator-tested | 2026-11-07 | Android app (minSdk 26, target 36), signed release APK from the release workflow (key `CN=Taskwise` in GitHub secrets and `~/.config/taskwise/`). `MobileNotifier` (iOS + Android, exact alarms via `USE_EXACT_ALARM`), WorkManager background sync, "Save to" export (`saveTextFile`). Location reminders in Kotlin (`app/packages/taskwise_android`): `GeofenceEngine.kt` port + `GeofencingClient` + precise-check foreground service + boot/update re-registration; 18 Kotlin tests incl. the walk simulator (8 walks, 300/300). `DeviceType.android` in shared and the server. Fixed on all platforms: Done on a set-time reminder of a one-off task opened it instead of ticking it off. Emulator (Pixel 9, Android 16, release build): time reminder on the minute with the app killed, Done/Snooze; fake walk with Google Maps keeping GPS on: Leave fired at 120 m, Arrive at 25 m, Done on a location notification ticked the task; geofences re-added after an app update; backup export/import; Back button. Not tested: sign-in/sync on Android (needs the maintainer's password), a real phone. 418 automated tests (app 211 + 1 live, shared 119, server 80) + 16 Swift + 18 Kotlin tests. |
| M11 Siri + Android shortcuts | ✅ Released (v1.1.0), device test pending | 2026-11-14 | Siri (App Intents, iOS 17+): add a task, add with a date (`DateComponents`, a day alone = all-day), what's due today/overdue; EN + AR phrases (`ar.lproj/AppShortcuts.strings`, `Localizable.strings`). Siri writes an inbox, the app imports it (start, resume, Siri while open, background sync) and writes a snapshot for "what's due" (`app/lib/assistant/`, `AssistantStore.swift`, `assistant.dart` in shared). Android: static "New task" shortcut and `ACTION_SEND text/plain` share target (`AssistantIntents.kt`), "Added …" message with Open. `ReminderRepository.addDefaultReminder` replaces four copies in the designs. Found by tests: an import started while another ran could miss a task Siri just added (now queued). Emulator (debug build): shortcut from Settings focuses quick add; share while open and from closed both add the task; Taskwise is listed as a share target. Siri compiled only by CI; not tried on the iPhone yet. 461 automated tests (app 225 + 1 live, shared 130, server 80) + 25 Swift + 22 Kotlin tests. |
| M12 In-app updates | ✅ Released (v1.1.0), device test pending | 2026-11-14 | Daily check of GitHub's latest published release, banner + dialog with the notes, Settings → About (check now, automatic switch). Signed releases: `tool/sign_release.sh` (SHA256SUMS + Ed25519 signature, checked against the app's key in the workflow), verified in the app with `cryptography` 2.9.0; key made locally (`~/.config/taskwise/update-signing-key.pem`), public key in `update_key.dart`. Installers: Windows (PowerShell + robocopy after quitting), Linux AppImage (rename over `$APPIMAGE`), Linux tar.gz (folder swap), restart through a detached `sh` waiting for the old pid; Android `PackageInstaller` (`AppUpdater.kt`); iPhone and source builds: notice + release page (`url_launcher` 6.3.3) and a SideStore source in each release. Found by tests: the saved "automatic" setting could overwrite a just-flipped switch. Emulator (debug builds, fake signed release from a local server): banner after 15 s, notes, download with progress, "Allow from this source" once, Android's update screen, updated to 1.2.0 with tasks kept; a retry reuses the verified download. Windows not tried (no Windows here). 468 automated tests (app 251 + 1 live, shared 137, server 80) + 25 Swift + 23 Kotlin tests. |

### How to test the latest milestone
Test steps are given to the maintainer in the chat at the end of each milestone. They are not kept here, because this file is public.

### Known issues
- **Tray (fixed in 1.0.0):** with tray_manager 0.7+ the menu only opens if `setContextMenuTrigger` is set (`app/lib/desktop/desktop_shell.dart`); on Linux, without it the icon reports `Menu = /NO_DBUSMENU`. Check it with D-Bus: `gdbus call --session -d <bus name> -o /StatusNotifierItem -m org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierItem Menu`.
- **Android (M10), tested on the emulator only.** Vendor battery savers (Samsung, Xiaomi …) can delay reminders and geofences; `docs/install-android.md` explains "Unrestricted" battery use. Geofencing needs Google Play services and **Location Accuracy** on (Location debug says so). Android shows at most 3 notification buttons, so with 3 snooze lengths the third is hidden. On the emulator, geofences only react while some app keeps GPS on (we used Google Maps); real phones also use Wi-Fi and cell.
- **iPhone:** SideStore can't sign in to Apple right now (-80045/-80046, Apple-side change from 2026-10-12). Taskwise is installed and refreshed weekly with iloader over USB instead. See Troubleshooting in `docs/install-ios-sidestore.md`.
- **Please review the Arabic text** (`app/lib/l10n/app_ar.arb`). Claude Code wrote the translations, and a native speaker should check them (M3 added the repeat and calendar texts, including Arabic plural forms; M7 added the location texts and `ios/Runner/ar.lproj/InfoPlist.strings`).
- **Location reminders:** "Leave" usually fires 150-400 m from the place on foot (after iOS reports leaving the ~100 m watched area), not at the 30 m radius. If you stand 30-50 m from the place's pin for more than 5 minutes (e.g. in the car in the driveway), "arrive" may not fire until you leave and come back. Accuracy indoors and in dense streets can be worse than 30 m; the debug screen shows the last position's accuracy. The map and address search need internet.
- `flutter pub get` reports that some packages "have newer versions incompatible with dependency constraints". This is expected and comes from the version pins below.
- Grouping is by date only: a task due at 9:00 today stays in **Today** after 9:00 rather than moving to Overdue. Its due label shows the time.
- The sort choice and collapsed groups reset when the app restarts (kept in memory only).
- Running `flutter run`/`build` from the repo root fails with `Target file "lib/main.dart" not found`. Run them from `app/`.
- GTK prints harmless `Atk-CRITICAL` / cursor-theme warnings to the terminal on GNOME.

### Notes for later
- **Updates (M12):** the MaterialBanner on phones leaves a gap under it (the page keeps its own top safe-area padding); cosmetic. On Android the app closes after updating itself and must be reopened (Android's behaviour). The Windows updater is untested on a real PC until the first update after 1.1.0. If the release key is lost or leaks, see docs/updates.md (one manual install everywhere).
- **Gemini (M11):** Gemini only calls other apps through AppFunctions (Android 16+, `androidx.appfunctions`), in a closed preview with trusted testers as of 2026-11; Google's Connected Apps platform (cloud MCP server or AppFunctions, Google Connected Console) opens in phases. When it opens, expose "add a task" and "what's due" as AppFunctions reusing the `taskwise/assistant` design (an inbox like the iPhone's, since Gemini may call while the app is closed). Old Assistant App Actions (`shortcuts.xml` capabilities) aren't invoked by Gemini.
- **Siri (M11, later):** the phrases can't carry the task title (Apple allows no free-text parameters in App Shortcut phrases). Siri tasks don't sync until Taskwise runs; pushing from Swift would need the token from the keychain and the sync API in Swift (not worth it now). A date-and-time said as exactly midnight is taken as all-day.
- **Android (M10):** building needs a full JDK 21 (`java-21-openjdk-devel`, see Where we left off). `workmanager_android` still applies the Kotlin Gradle plugin; Flutter warns that future versions will refuse such plugins, so update workmanager when it migrates to built-in Kotlin. `androidx.core` is pinned to 1.18.0 because 1.19 needs compileSdk 37. Gradle's heap is capped at 3 GB (`app/android/gradle.properties`) so builds fit next to the emulator. `adb emu kill`/`adb reboot` may stop the T3-started emulator; use the device panel to start it. `am force-stop` cancels an app's alarms (as Settings → Force stop does), so test "app closed" with Home + swipe away instead.
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
