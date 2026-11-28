# app/web

The files of the browser build (Flutter web), copied as they are into
`build/web/`. This note lives outside `web/` so it isn't published with them.

Build with our own service worker instead of Flutter's:

```sh
flutter build web --pwa-strategy=none
```

| File | What it is |
| --- | --- |
| `index.html` | Title, theme colours (Brutal light/dark), iPhone Home Screen tags, takes `#server=` and `#task=` out of the address, registers `sw.js`, then loads `flutter_bootstrap.js` |
| `manifest.json` | Name, icons, `display: standalone`, Brutal colours |
| `sw.js` | Our service worker (below) |
| `icons/` | Generated from the iOS app icon (below) |
| `sqlite3.wasm`, `drift_worker.js` | The database (below) |
| `fallback-fonts/` | Roboto, the engine's default font (below) |

## The service worker

`sw.js` keeps the app's own files for an offline start:

- network first only for `index.html` (and every page load) and
  `manifest.json`, with a 4 s timeout: on a very slow connection the
  cached copy answers, and the network's answer is still saved for next
  time (without a cached copy it keeps waiting). Everything else in the
  app's folder is cache first from the version's cache,
  `flutter_bootstrap.js` too: it goes with `main.dart.js`, so a page that an older worker still controls never mixes
  old and new files;
- every file it puts in the cache is fetched with `cache: 'no-cache'`
  (revalidated with the server), because Flutter doesn't hash the names of
  CanvasKit and the assets and the browser's own cache could hold old copies;
- one online visit is enough for an offline start. Installing fetches the
  main files (`index.html`, `flutter_bootstrap.js`, `manifest.json`,
  `main.dart.js`, `sqlite3.wasm`, `drift_worker.js`). On the first visit the
  rest (CanvasKit, fonts, `assets/`) loads before the worker controls the
  page, so when it takes over, `index.html` posts `{type: 'cache', urls}`:
  the page's address plus the app files from
  `performance.getEntriesByType('resource')` (and, through a
  `PerformanceObserver`, the ones that finish later). The worker caches
  those it doesn't have yet, only from the app's folder;
- never other sites (the sync server, map tiles) and never anything but GET;
- one cache per version, `taskwise-app-<version>`. `const CACHE_VERSION =
  '{{VERSION}}'` is replaced by the site build with the release version. Left
  as it is (a dev build, `flutter run`), the worker caches nothing.
- When a new version has installed while an older one runs, it posts
  `{type: 'new-version'}`. The page (`index.html`) then sets
  `window.taskwiseNewVersionReady`, fires a `taskwise-new-version` event, and
  the app shows "A new version of Taskwise is ready. · Reload"
  (`lib/platform/web_shell.dart`, `lib/ui/shared/web/new_version_bar.dart`).
  Reload calls `window.taskwiseReloadToNewVersion()`, which posts
  `{type: 'reload'}`; the worker skips waiting, takes over, and the page
  reloads. On `activate`, the older caches are deleted.
- So installing a new version is all or nothing: besides the main files it
  copies every file of the older versions' caches into its own, fetched
  fresh (CanvasKit, fonts, assets: the files an offline start needs). If
  one can't be fetched (offline, a server error), the install fails and the
  running version keeps serving; the browser tries again at a later visit.
  An older file the new version no longer has (404) is left out. Without
  this, a new version that installed and waited (the tab closed without
  Reload) would take over at the next start, delete the older cache, and
  start offline without CanvasKit: a blank page.

It also shows the reminders the sync server sends as Web Push (in dev builds
too; the web app subscribes in Settings → Notifications,
`lib/ui/shared/settings/web_notifications_section.dart`):

- `push`: always shows a notification (iOS stops pushing to a site that
  shows none), with the payload's title and body, `tag` = its key and
  `data.taskId`. An unreadable payload shows a plain "Taskwise reminder". No
  action buttons (iOS shows none).
- `notificationclick`: focuses an open window of the app and posts
  `{type: 'open-task', taskId}`, or opens `./#task=<id>`. `index.html` takes
  `#task=` out of the address before Flutter starts and, like the message,
  sets `window.taskwisePendingTask` and fires `taskwise-open-task`; the app
  opens the task (`WebShell.openTaskRequests`,
  `lib/ui/shared/web/open_task_listener.dart`).

`web/test_site_browser.mjs` checks this in Chrome on a built site (CI's `web`
job runs it): version 1 is visited, version 2 installs and waits, the tab
closes, the server goes away, and a new tab must start the app; then a
server that never answers; that a first visit, in English and in Arabic,
fetches only from the site itself; and that a push shows its notification
and opens the task.

Check the syntax after a change: `node --check web/sw.js`.

## Fonts: nothing from Google

Flutter's engine always loads Roboto (its default font) and, for a character
no loaded font has, a Noto font, from `fontFallbackBaseUrl`
(`https://fonts.gstatic.com/s/` unless set). `flutter_bootstrap.js` sets it
to `fallback-fonts/`, which holds the one file the engine asks for:

| File | Source | sha256 |
| --- | --- | --- |
| `fallback-fonts/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2` | https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2 (the engine's `_robotoUrl`) | `35b02ca266b79eb4996590f15817425a1ce9ebf48f84471843233ff614656bf2` |

Roboto is under the SIL Open Font License (`fallback-fonts/OFL-Roboto.txt`).
After a Flutter upgrade, check the engine still asks for that path
(`grep -rn _robotoUrl` in `bin/cache/flutter_web_sdk/` of the Flutter SDK).
Every text in the app uses the bundled fonts (Brutal: Space Grotesk +
Alexandria, Lapis: IBM Plex Sans Arabic), so no Noto font is needed; text
must not use characters these lack (e.g. write "the three dots", not "⋯").
The browser test checks that a start in English and Arabic, in both designs,
contacts no other host.

## The icons

From the iOS app icon (1024 px, full bleed on the Brutal paper colour
`#F7F0E1`), with ImageMagick 7, in `app/web/`:

```sh
I=../ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
magick $I -resize 192x192 -strip icons/Icon-192.png
magick $I -resize 512x512 -strip icons/Icon-512.png
# Maskable: the icon in the middle 80 % (the safe zone) on the paper colour.
magick $I -resize 410x410 -background '#F7F0E1' -gravity center -extent 512x512 -strip icons/Icon-maskable-512.png
magick $I -resize 180x180 -strip icons/apple-touch-icon.png
magick $I -resize 32x32 -strip icons/favicon-32.png
magick $I -resize 48x48 -strip icons/favicon-48.png
```

## The database files

The web app's database is drift's WebAssembly build of SQLite
(`AppDatabase.openConnection` in `lib/data/db/app_database.dart`). It needs two
files next to `index.html`. They must match the `drift` and `sqlite3` versions in
the repo's `pubspec.lock`: download them again whenever those change.

| File | Version | Source | sha256 |
| --- | --- | --- | --- |
| `sqlite3.wasm` | sqlite3 3.7.1 | https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.7.1/sqlite3.wasm | `87c1869b533ea4b6daa1f4dc6aa7e9cf3dae6e6ea53f8ed57080c08eb5f64303` |
| `drift_worker.js` | drift 2.35.2 | https://github.com/simolus3/drift/releases/download/drift-2.35.2/drift_worker.js | `191fc9db018d2bbecb1723e81118fcf2c5c094df8644c2fcba2ed51df061e90a` |

The sha256 values match the digests GitHub shows for these release assets.

To update them, in `app/web/`:

```sh
# Versions from pubspec.lock (repo root)
grep -A6 '^  sqlite3:\|^  drift:' ../../pubspec.lock | grep version
dir=$(mktemp -d)
gh release download sqlite3-<version> -R simolus3/sqlite3.dart -p sqlite3.wasm -D "$dir"
gh release download drift-<version> -R simolus3/drift -p drift_worker.js -D "$dir"
head -c 4 "$dir/sqlite3.wasm" | od -An -tx1   # must be 00 61 73 6d
sha256sum "$dir"/*                            # compare with the release page
cp "$dir/sqlite3.wasm" "$dir/drift_worker.js" .
```

Then update the table above.
