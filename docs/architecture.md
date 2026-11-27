# How the code is organized

Taskwise is three projects in one repository:

| Folder | What it is |
|---|---|
| `app/` | The Flutter app for Linux, Windows, iPhone, Android and the web. The web shell (page, service worker, database files) is in `app/web/` (see `app/web_README.md`). |
| `app/packages/taskwise_android/` | Taskwise's own Android code as a local plugin: location reminders (`GeofenceEngine.kt`, a port of the Swift engine, and `LocationReminderManager.kt`), the "Save to" dialog, and the "New task" shortcut and share (`AssistantIntents.kt`). A plugin, so it is also registered in the background-sync engine. |
| `shared/` | Pure Dart models and logic used by the app (and mirrored by the server's tests): tasks, reminders, places, repeat rules, the reminder schedule, task grouping, the location plan. No Flutter in here. |
| `server/` | The TypeScript + Hono sync server (Vercel + Turso). API: `docs/sync-api.md`. |
| `tools/geofence_sim/` | The walk simulator and Linux runner for the iPhone's Swift location code (the Android twin is `GeofenceWalkTest.kt`). |
| `design/` | Screenshots of every design (made by the design tour, see below). |
| `web/` | The public home page (`web/site/`, English and Arabic) and the scripts that build and check the whole site, with the app under `/app/` (`build_site.sh`, `test_site.sh`). Deployed by `.github/workflows/web.yml`. |
| `docs/` | Setup and install guides, the sync API, this file. |

## Inside `app/lib/`

| Folder | What lives there |
|---|---|
| `main.dart`, `bootstrap.dart`, `app.dart` | Start-up (database, device id, settings) and the app root. `app.dart` picks the theme and the first screen from the chosen design. |
| `data/` | The drift database (`db/`), repositories that read and write it (`repositories/`), `app_settings.dart` (all user settings, including the design) and `backup.dart` (JSON export/import, merged like a sync). |
| `logging/` | `appLog`: the app's log (memory + a rotating file in the app support folder), and the hooks that log uncaught errors. Never log task titles, notes, places or tokens. |
| `state/` | Riverpod providers shared by everything: the database, repositories, today's date, the open task, the selected tab, which tasks have their subtasks unfolded. `missed_repeats.dart` gives repeating tasks that weren't done in time their next copy (at start, at midnight, on resume and when tasks change). |
| `sync/` | Talking to the sync server: the API client, the sync engine and controller, the token store. |
| `notifications/` | Time reminders: scheduling, the desktop notifier and the phones' notifier (`mobile_notifier.dart`, iPhone and Android). |
| `location/` | Location reminders: the address search, the bridge to the phones' native code (`taskwise/location` channel: Swift on the iPhone, Kotlin on Android, same methods), keeping the phone's list up to date. |
| `background/` | The phones' background sync job (iOS background refresh, Android WorkManager). |
| `update/` | In-app updates: checking GitHub Releases, verifying the signed `SHA256SUMS`, and the installers for Windows, the Linux AppImage and tar.gz, and Android (`AppUpdater.kt`, channel `taskwise/update`). See `docs/updates.md`. |
| `assistant/` | Siri's inbox and snapshot on the iPhone, and Android's "New task" shortcut and share (channel `taskwise/assistant`: `AssistantPlugin.swift` and `AssistantIntents.swift` on the iPhone, `TaskwiseAndroidPlugin.kt` on Android). See `docs/assistants.md`. |
| `desktop/` | Tray icon, single window, start on login. |
| `platform/` | Which kind of device the app runs on. `AppTarget` (`app_target.dart`) replaces `Platform.isX` checks (`dart:io`'s `Platform` throws in a browser). Browser-only code (`package:web`, `dart:js_interop`: storage, the service worker, the browser name, the Home Screen guide) sits behind conditional imports, `if (dart.library.js_interop)`, with a plain Dart twin for the VM so tests still compile. Tests set `debugAppTargetOverride` (`test/flutter_test_config.dart` sets it to the host). |
| `version.dart` | The app version (a test keeps it equal to `pubspec.yaml`). |
| `l10n/` | English and Arabic texts (`app_en.arb`, `app_ar.arb`); the Dart files next to them are generated. |
| `ui/` | Everything on screen, split by design (below). |

None of the folders outside `ui/` know which design is in use.

On the web only Brutal and Lapis are offered (any other stored design shows Brutal), and a few things are off: reminders, location, background sync, in-app updates (each checks `AppTarget`). See `docs/web-app.md`.

## Designs (`app/lib/ui/`)

The app has four designs, picked per device in **Settings → Appearance → Design**:

| Design | Folder | Fonts |
|---|---|---|
| Classic (the original) | `ui/designs/classic/` | Noto Sans + Noto Sans Arabic |
| Lapis | `ui/designs/lapis/` | IBM Plex Sans Arabic |
| Slate & Indigo | `ui/designs/slate/` | Noto Sans + Noto Sans Arabic |
| Brutal (the default) | `ui/designs/brutal/` | Space Grotesk + Alexandria |

```
ui/
  designs/
    design.dart      the list of designs: each one's light/dark theme and its shell
    classic/ lapis/ slate/ brutal/
                     each design's own screens: shell (navigation), task list,
                     task details, calendar, settings, theme
  shared/            screens and widgets every design uses as they are: sign-in,
                     sync section, devices, categories, location permission and
                     debug, the map's providers, dialogs, the repeat editor,
                     subtasks, labels, base tokens (spacing, breakpoints), the
                     design picker, Backup, About and the logs page, and
                     messages (`common/messages.dart`: showMessage, guardAction)
```

**Unfolding subtasks and Skip (M13).** The behaviour is shared and the look is per design:
`ui/shared/tasks/task_actions.dart` has `handleTaskTap` (what a tap on a task does, following
the "Tapping a task with subtasks" setting), `showsDetailsArrow` and `skipTask`, and
`ui/shared/tasks/subtask_tree.dart` draws the subtasks on a tree line. Each design passes a
`SubtaskTreeStyle` from `designs/<name>/tasks/subtask_tree_style.dart` and draws its own
Skip button and skipped look. The mockups each design follows are in `design/m13/`.

**How a design finds a file.** A design folder holds only the files that design changed. For any other file it uses Classic's copy, and otherwise the one in `shared/`. For example, Lapis has no reminder editor of its own, so its task details import `designs/classic/tasks/reminder_editor.dart`. Shared files never import from a design folder.

**Themes do most of the work.** Shared screens take their colours, fonts and shapes from the current design's theme, so the sign-in page looks right in every design without four copies.

### How to change a screen

1. Find every copy of it: `find app/lib/ui -name task_detail.dart`.
2. Change each copy, or the shared one if it lives in `shared/`.
3. New texts go in both `app_en.arb` and `app_ar.arb`.
4. Run the tests (`flutter test` runs every design's widget tests) and the design tour, then look at the new screenshots for every design.

Keep new screens in `shared/` unless a design really needs its own version, so a new feature is built once.

### How to add a design

1. Add a value to `AppDesign` in `data/app_settings.dart`.
2. Create `ui/designs/<name>/` with at least `theme/app_theme.dart` (an `AppTheme` with `light()` and `dark()`) and `shell/adaptive_shell.dart` (an `AdaptiveShell`). Copy the Classic files you want to change; everything else falls back to Classic.
3. Register it in `ui/designs/design.dart`, and give it a name and swatch in `ui/shared/settings/design_picker.dart` (texts `design<Name>` in both ARB files).
4. Add the design picker row to its settings page.
5. Add its fonts to `app/pubspec.yaml` (open-licensed, with the licence file in `app/assets/fonts/`).
6. Add `test/widget/designs/<name>_app_test.dart` (copy another design's and pin the design with `appDesignProvider`).

## Tests

| What | Command (from `app/`) |
|---|---|
| Widget tests, every design | `flutter test` (take ccache off `PATH` first) |
| Switching designs | `flutter test test/widget/design_switch_test.dart` |
| The real app in a window: places, location reminders, the map | `flutter test integration_test/location_test.dart -d linux` |
| Screenshots of every screen, design and look | `flutter test integration_test/design_tour_test.dart -d linux --dart-define=SHOTS=$PWD/../design` |
| Speed with 2,000 tasks, every design | `flutter drive --profile -d linux --driver=test_driver/integration_test.dart --target=integration_test/performance_test.dart` (see `docs/performance.md`) |
| The web app in Chrome against a local server | `flutter drive -d web-server ... --target=integration_test/web_smoke_test.dart` (see `docs/dev-setup-fedora.md`, "The browser test") |
| The built site | `web/build_site.sh <version> <out_dir> && web/test_site.sh <out_dir>` |
| Shared logic | `cd shared && dart test` |
| Server | `cd server && npm test` |
| iPhone location logic and Siri's inbox | `tools/geofence_sim/run.sh test` and `tools/geofence_sim/run.sh` |
| Android location logic, shortcut and share (unit tests and the walk simulator) | `cd android && JAVA_HOME=$HOME/.local/jdk-21 ./gradlew :taskwise_android:testDebugUnitTest` (build the APK once first) |
| Android app on the emulator | `flutter run -d emulator-5554` (see `docs/install-android.md` for Location Accuracy) |
