# Changelog

All notable changes to Taskwise are written here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the versions follow [Semantic Versioning](https://semver.org/).

When a version is released, its section becomes the text of the draft GitHub release (see [CONTRIBUTING.md](CONTRIBUTING.md#releases)).

## [Unreleased]

## [1.1.0] - 2026-11-12

### Added

- **Siri on the iPhone** ([how to use it](https://github.com/Krkr8/taskwise/blob/main/docs/assistants.md)), in English and Arabic, without opening Taskwise:
  - "Add a task in Taskwise": Siri asks "What's the task?" and adds it.
  - "Add a task with a date in Taskwise": Siri also asks "When is it due?". Say a day ("tomorrow") for an all-day task, or a day and a time ("Friday at 5 pm").
  - "What's on my list in Taskwise": Siri reads the tasks due today and the overdue ones.
  - The commands are in the Shortcuts app too, so they can go on the Action Button or the home screen.
  - A task added by Siri reaches your other devices the next time Taskwise opens or syncs in the background.
- **Updates inside the app** ([how it works](https://github.com/Krkr8/taskwise/blob/main/docs/updates.md)). Taskwise checks for a new version about once a day and shows a banner with what's new. On **Windows and Linux** (AppImage or tar.gz), **Update and restart** downloads it, checks it, installs it and starts the new version. On **Android**, **Update now** hands it to Android's update screen. Your tasks and sign-in are kept. **Settings → About** has **Check for updates** and a switch to turn the daily check off.
  - Every release is signed: Taskwise installs only files listed in a release's `SHA256SUMS` with a valid signature from the Taskwise release key.
  - **iPhone:** iOS apps can't update themselves, so Taskwise only tells you and links to the release. Each release also has a SideStore source, so SideStore can update Taskwise on the phone once its sign-in works.
  - **This version is the last one to install by hand.**
- **Android:** long-press the Taskwise icon for **New task**, which opens Taskwise ready to type. **Share to Taskwise** from any app turns the shared text into a task: the first line (or the page title) is the title, and the rest goes into the notes.

### Changed

- The default reminder for a task's first due time is added in one place now, so every design and Siri behave the same.

## [1.0.0] - 2026-11-07

The first stable version, for every platform: Windows, Linux (AppImage and tar.gz), Android and iPhone. It includes everything from 0.6.1 and 0.7.0 (the Linux AppImage and the Android app), which were never published on their own.

### Fixed

- **The tray menu (Show Taskwise / Quit Taskwise) is back on Windows and Linux.** Right-click the tray icon to open it. The menu didn't open: the tray library shows it only when told which click opens it, and on Linux it didn't even offer the menu to the panel.

## [0.7.0] - 2026-11-07

### Added

- **Android app** (Android 8.0 or newer): `taskwise-<version>-android.apk` on the release page ([how to install](https://github.com/Krkr8/taskwise/blob/main/docs/install-android.md)). Everything the iPhone app does:
  - Time reminders that come on the minute with the app closed and after a restart, with Done and Snooze buttons.
  - **Location reminders** (Arrive / Leave), watched by Android even when Taskwise is closed. The same rules as on the iPhone (an outer area, then a precise check for up to 5 minutes), ported to Kotlin and checked with the same walk simulator. They need "Allow all the time" location access and Google Play services.
  - Sync in the background about every 30 minutes.
  - Backup and logs are saved with Android's "Save to" screen.
- Settings → Location reminders on Android: location access, the debug screen, and a hint about battery savers.

### Changed

- Location reminders made on a computer now say "Only reminds on phones (iPhone and Android)".
- The sync server accepts Android devices. **Deploy the server (push to `main`) before signing in on an Android phone.** Older apps show an Android device as "other".

### Fixed

- **Done** on a reminder at a set date and time now ticks the task off when that day isn't the task's due date (or the task has none). Before, it only opened the task. Repeating tasks still need the reminder of the current occurrence.

## [0.6.1] - 2026-11-07

### Added

- **Linux AppImage:** `taskwise-<version>-linux-x86_64.AppImage` is one file that runs on Debian 12+, Ubuntu 22.04+, Arch, Fedora and most other distributions. Make it executable and open it ([how](https://github.com/Krkr8/taskwise/blob/main/docs/install-linux.md#appimage-any-distribution)). The tar.gz with `install.sh` is still there.

### Changed

- The Linux builds are made on Ubuntu 22.04, so they also run on distributions older than the newest Ubuntu.

### Fixed

- "Start when I log in" works from the AppImage: it starts the AppImage file, not the temporary folder the AppImage runs from.

## [0.6.0] - 2026-11-07

### Added

- **Settings → Backup:** export all your data to a JSON file, and import one again. An import merges: newer changes on the device are kept, tasks deleted since the backup come back, and everything syncs to your other devices. On the iPhone the file is in the Files app → On My iPhone → Taskwise.
- **Settings → About:** the version, and a logs viewer (all lines or problems only, copy, save, clear). Logs never contain task titles, notes, places or passwords.
- Errors nobody expected are written to the log, and the app shows a short message instead of the raw error.
- A README with screenshots, [CONTRIBUTING.md](https://github.com/Krkr8/taskwise/blob/main/CONTRIBUTING.md), a [self-hosting guide](https://github.com/Krkr8/taskwise/blob/main/docs/self-hosting.md) for running the sync server with Docker or Node.js, and this changelog. Draft releases now take their notes from it.

### Changed

- Settings is centred on wide windows (it used to sit on the left half).
- The cloud button in the side bar syncs when you press it (it used to open Settings).
- Taskwise stays fast with 2,000 tasks: the task list builds only the rows on screen, and tabs are built when first opened ([numbers](https://github.com/Krkr8/taskwise/blob/main/docs/performance.md)).

### Fixed

- Long words in the phone's week view no longer break in the middle ("electric / ity"); the title shrinks a little instead.

## [0.5.0] - 2026-11-06

### Added

- Four designs, chosen separately on each device in Settings → Appearance → Design: **Classic** (the original), **Lapis**, **Slate & Indigo** and **Brutal**. Every design has a light and a dark look and works in English and Arabic.
- Desktop keyboard shortcuts in Lapis and Brutal: `Ctrl+N` new task, `Ctrl+F` search, `Esc` closes the open task.
- A new app icon.
- Screenshots of every screen of every design in `design/`, and [docs/architecture.md](https://github.com/Krkr8/taskwise/blob/main/docs/architecture.md), which explains how the code is organised.

### Changed

- **Brutal** is now the default design (cream paper, black outlines, hard shadows). Its dark mode is a warm charcoal.
- The screens moved into `app/lib/ui/shared/` and `app/lib/ui/designs/<name>/`. Your tasks and sign-in are kept.

## [0.4.1] - 2026-11-06

### Fixed

- iPhone location reminders: no more false "arrived" while sitting at home after one noisy indoor position.
- iPhone location reminders: "arrive" is no longer missed after lingering near the place for more than five minutes.
- iPhone location reminders: a wrong "you left" report from iOS is checked with precise positions before a reminder fires.
- Long place names in the reminder chip end with "…" instead of overflowing.

### Changed

- The iPhone's location decisions moved into one piece of code that is tested on Linux with a walk simulator (`tools/geofence_sim`) and Swift unit tests.

## [0.4.0] - 2026-11-05

### Added

- **Location reminders** (they fire on the iPhone only): pick a place on a map (OpenStreetMap, with address search) or a saved place, choose **Arrive** or **Leave**, and set a radius from 30 to 500 m. A reminder fires every time, at most once per 30 minutes.
- Saved places (Home, Work, …) in Settings. Moving a place moves its reminders.
- A default radius for location reminders (synced), a location permission explanation and banner in English and Arabic, and a location debug screen on the iPhone.
- iPhone background sync: iOS can now run a sync in the background and refresh your reminders.

## [0.3.2] - 2026-11-05

### Changed

- The Undo bar fades away after 5 seconds.

## [0.3.1] - 2026-11-03

### Added

- A **main device**: the first device to sign in manages the account's other devices (rename, remove, pass the role on). A lost main device can be replaced with the account password.
- Settings → Notifications → "Send a test notification".
- Reminders whose time has passed are marked in the task.

### Fixed

- Desktop lists can be dragged with the mouse and show scrollbars (Settings did not scroll on Windows).
- The tray menu's **Quit** always exits.
- iPhone: new reminders were not scheduled after a change.

## [0.3.0] - 2026-11-02

This version adds everything since 0.1.1 (there was no 0.2.0).

### Added

- **Sync across devices.** Sign in from Settings → Sync to a server that you host yourself ([guide](https://github.com/Krkr8/taskwise/blob/main/docs/server-setup-vercel.md)). Changes sync within a minute, work offline, and settings like the week start are shared. Settings → Sync → Devices lists your devices.
- **The sync server** (`server/`, TypeScript + Hono): one account, per-device tokens you can revoke, a daily clean-up and backup. It runs on Vercel with Turso, or as a Docker or Node.js server. The [API](https://github.com/Krkr8/taskwise/blob/main/docs/sync-api.md) is documented.
- **Calendar** with a week view and a month view on all platforms.
- **Repeating tasks:** daily, weekly on chosen days, monthly, yearly, every N days/weeks/months, with an end date or count. Completing one creates the next.
- **Time reminders:** at a set time or before the due time, several per task, with **Done** and **Snooze** on the notification. Choose which devices a task reminds on ("Notify on").
- On desktop, Taskwise stays in the tray so reminders keep firing, runs as a single window, and can start when you log in.

## [0.1.1] - 2026-10-30

### Fixed

- iPhone: the keyboard closes when you tap outside a text field or scroll the list.
- Selected options in Settings use the accent colour.

## [0.1.0] - 2026-10-21

The first release.

### Added

- Tasks with notes, due date and time, priority, categories and tags, and subtasks.
- Search, filters and sorting, quick add, and Undo for deletes.
- English and Arabic (right to left), light and dark themes, week start, and time format settings.
- Builds for Linux, Windows and iPhone (unsigned, installed with SideStore or iloader) made by GitHub Actions, with install guides.

[Unreleased]: https://github.com/Krkr8/taskwise/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/Krkr8/taskwise/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Krkr8/taskwise/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/Krkr8/taskwise/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/Krkr8/taskwise/compare/v0.3.2...v0.4.0
[0.3.2]: https://github.com/Krkr8/taskwise/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/Krkr8/taskwise/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Krkr8/taskwise/compare/v0.1.1...v0.3.0
[0.1.1]: https://github.com/Krkr8/taskwise/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Krkr8/taskwise/releases/tag/v0.1.0
