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
| Desktop PC | Windows 11 | App **and** sync server (the hub). Always on, internet 24/7. |
| Laptop | Fedora 44, GNOME (Wayland) | App. Development machine. |
| Phone | iOS 27 (iPhone) | App. **Only device that does location reminders.** |

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
- **Server (sync hub):** Dart (`shelf`) compiled to a native executable, SQLite storage.
  - Shares model code with the app via a `shared` Dart package.
  - Runs on Windows as a background service / auto-start task. Also provide a Dockerfile (for future open-source users on Linux).
- **Networking between devices:** **Tailscale** (free private network). The server listens only on the Tailscale interface/LAN by default. No port forwarding.
  - Note for docs: iOS allows one VPN at a time. Tailscale must be on for the phone to sync; SideStore's refresh may briefly need its own VPN. Document this.
  - Optional alternative (document only, not default): Cloudflare Tunnel with HTTPS.
- **CI/CD:** GitHub Actions: tests, Linux build, Windows build, unsigned iOS .ipa, server binaries. Artifacts attached to GitHub Releases.
  - Note: macOS runners consume more minutes on private repos; public repos are free. Check current GitHub pricing and tell the owner.

### Repo layout
```
/app        Flutter app (windows, linux, ios)
/server     Dart sync server
/shared     Shared models, sync protocol, recurrence logic
/docs       Setup guides (install, Tailscale, SideStore, server service)
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
- **Reminders** (0 or more per task, see 3.3)
- **Notify on devices:** a set of registered devices. **Default = all devices.**
- Created/updated timestamps, soft-delete (tombstone) for sync

### 3.2 Views
- **List view:** groups: Overdue, Today, Tomorrow, This week, Later, No date, Completed (collapsible). Filter by category, priority, tag; search by text; sort options.
- **Weekly calendar view:** 7 columns, week starts on the day chosen in settings (**default Sunday**). Timed tasks placed at their time, all-day tasks in a top row. Swipe/arrow to previous/next week, "Today" button. Tap a day to add a task on that day. Drag a task to another day/time (desktop) — nice to have.
- Quick add: a single input field on all views (title + Enter); details editable after.
- Task detail / edit screen or side panel (side panel on wide screens, full screen on phone).

### 3.3 Reminders
Two types, a task can mix both:

**Time reminder**
- Absolute (specific date & time) or relative to due time (e.g., 1 day before, 1 hour before, at due time). Multiple allowed.
- Repeating tasks: reminders follow each occurrence.
- Fires as a system notification on each device in the task's "Notify on devices" set (each device schedules its own local notifications after sync).
- Notification actions where the platform supports them: **Done**, **Snooze** (5 / 15 / 60 min, configurable).

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
- One account (username + password) on the server. Set up on first server start (setup page in the app or CLI command).
- Each app install = a **device**. On first launch: enter server address, log in, give the device a name (pre-filled: "Windows PC", "Fedora Laptop", "iPhone"), device type is detected.
- Server issues a per-device token (revocable). Store tokens securely (Windows Credential Manager / libsecret / iOS Keychain via `flutter_secure_storage`).
- **Settings → Devices:** list devices (name, type, last seen), rename, remove/revoke.
- New devices are added to "Notify on devices" for tasks that use the default "All devices" (store "all" as a flag, not as a list, so new devices are included automatically).
- Passwords hashed with a strong algorithm (argon2 or bcrypt). Rate-limit login.

### 3.5 Settings
- Theme: System / Light / Dark
- Language: English / Arabic (switches layout to RTL)
- Week starts on: Sunday (default) / Saturday / Monday
- Time format: 12h / 24h
- Default reminder (e.g., none / at due time / 15 min before)
- Default snooze durations
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
- Responsive: phone layout (bottom nav: List / Week / Settings), desktop layout (side nav + optional detail panel).
- Accessible: proper contrast in both themes, readable sizes, screen-reader labels.

---

## 4. Sync design

- **Local-first:** every device has its full local SQLite DB and works offline. Sync is background and automatic.
- Every record (task, subtask, reminder, category, place, setting) has: `id` (UUID v4/v7), `updatedAt` (hybrid logical clock or server-assigned sequence), `deleted` flag, `updatedByDevice`.
- Server keeps a monotonically increasing **change sequence number**. Clients:
  - **Push:** send all local changes since last successful push.
  - **Pull:** `GET /sync?since=<seq>` returns all changes after that sequence.
- Conflict rule: **last write wins per record** (good enough: single user, one device at a time). Keep it simple, but structure code so field-level merge could be added later.
- Tombstones: deleted records sync as `deleted=true`; server purges tombstones older than 90 days.
- Sync triggers: app start/resume, after any local change (debounced ~2 s), every 1–2 min while app open, iOS background refresh, iOS geofence wake (if quick), manual "Sync now".
- After each pull, each device **rebuilds its scheduled local notifications** for tasks targeted at that device (cancel stale ones, schedule new ones; iOS has a 64 pending-notification limit — schedule the soonest 64 and refresh on sync/app open).
- Device-only settings (theme, language, etc.) can be local; shared data (categories, places, week start) syncs. Decide per setting and document it.
- API: JSON over HTTP, versioned (`/api/v1/...`), token auth in header. Endpoints at minimum: `POST /auth/login`, `POST /auth/setup`, `GET/POST /sync`, `GET/PATCH/DELETE /devices`, `GET /health`.
- Server listens on Tailscale/LAN; document how to find the PC's Tailscale address (MagicDNS name like `my-pc`). Plain HTTP over Tailscale is acceptable (Tailscale encrypts); support HTTPS if a cert is configured.
- Server backups: daily SQLite backup copy, keep last N.

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
- Recurrence rules per 3.1, with editor UI and solid tests (DST, month ends, leap years, "2nd Tuesday", timezone Asia/Baghdad and others).
- **Done when:** repeating tasks show correctly in list and week view on all devices.

### M4 — Time reminders & notifications
- Time reminders (absolute + relative, multiple per task), scheduling engine in `shared` (pure, tested), platform notification layer.
- Notification actions Done / Snooze where supported; tapping a notification opens the task.
- iOS 64-pending limit handling; reschedule on app start and data change.
- Windows: notifications even when the window is closed → minimize to system tray + start on login option. Linux (GNOME): same, with a background/autostart option (document GNOME tray limitations; use a background mode if no tray).
- **Done when:** reminders fire reliably on all three devices (owner tests with a list you provide).

### M5 — Sync server
- Dart `shelf` server per section 4: setup, login, devices, sync endpoints, SQLite, logging, daily backup, config file (port, bind address, data dir).
- Run as a Windows background service / Task Scheduler auto-start (choose the simplest reliable method and script it), plus Dockerfile and Linux systemd example.
- CI builds server executables (Windows + Linux).
- `docs/server-setup-windows.md` and `docs/tailscale.md` (install Tailscale on all devices, find the PC's address).
- Integration tests for the sync protocol.
- **Done when:** server runs on the Windows PC and survives reboot; `GET /health` reachable from the laptop and iPhone over Tailscale.

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

### M8 — Polish & open-source readiness
- Animation polish, empty states, onboarding hints, app icon, accent colors.
- JSON export/import, error handling, logs viewer.
- Performance check (1,000+ tasks).
- README with screenshots, CONTRIBUTING, self-hosting guide, versioned GitHub Releases.
- **Done when:** owner signs off.

---

## 6. Owner's preferences (summary)
- Single user now; maybe public open-source self-hosted later.
- Windows PC is the always-on sync hub; internet 24/7 on PC and phone.
- Location reminders only on iPhone; default radius 30 m; arrive/leave selectable.
- Week starts Sunday by default, changeable in settings.
- English + Arabic, switchable in settings.
- Notifications on all devices by default, selectable per task.
- Simple design, light/dark mode, subtle hover animations.
- Owner is comfortable with the terminal but not a mobile developer — explain device-side steps clearly.

---

## 7. Progress Log

| Milestone | Status | Date | Notes |
|---|---|---|---|
| M0 Project setup | ✅ Done | 2026-10-20 | Flutter 3.47.7 workspace (app/server/shared), placeholder screen, CI green. |
| M1 Core app | ⬜ | | |
| M2 Build pipeline | ⬜ | | |
| M3 Week view + recurrence | ⬜ | | |
| M4 Time reminders | ⬜ | | |
| M5 Sync server | ⬜ | | |
| M6 Client sync + devices | ⬜ | | |
| M7 Location reminders | ⬜ | | |
| M8 Polish | ⬜ | | |

### How to test the latest milestone
**M0** (on the Fedora laptop; first-time setup is in `docs/dev-setup-fedora.md`):
1. `cd ~/Documents/projects/taskwise`
2. `flutter pub get`, then `flutter analyze`. This should print "No issues found!".
3. `cd app && flutter test`. This should print "All tests passed!".
4. `flutter run -d linux` (from inside `app/`). A "Taskwise" window opens showing a check icon and "Coming soon: your tasks." Press `q` in the terminal to quit.
5. CI: https://github.com/Krkr8/taskwise/actions should show a green check for the latest commit.

### Known issues
- The Linux window title bar says "taskwise" in lowercase (the Flutter default). Fix planned for M1.
- `flutter pub get` reports "7 packages have newer versions incompatible with dependency constraints". This is expected and comes from the version pins below.

### Notes for later
- **`test` is pinned to 1.31.1** because Flutter 3.47.7's `flutter_test` pins `test_api` 0.7.12, and a pub workspace resolves to one version. Whenever Flutter is upgraded, bump `test` (in shared and server) to the release that uses the new `test_api`. The same constraint caps `analyzer` below 14, which keeps `build_runner` at 2.15.x.
- Flutter's version is pinned in two places: `.github/workflows/ci.yml` and `docs/dev-setup-fedora.md`. Keep them in sync.
- GitHub notice (2026-10-20): the `ubuntu-latest` runner label is moving to Ubuntu 26 (from 2026-10-19). Consider pinning an explicit runner image in M2.
- Flutter commands must run from `app/` (the Flutter project), not the repo root. `flutter pub get` and `flutter analyze` work from the root.
