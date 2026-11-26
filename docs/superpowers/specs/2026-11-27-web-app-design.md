# Taskwise on the web, with reminders (design)

Asked for by the maintainer on 2026-11-26/27. Decided in the conversation unless marked
**(builder's call)** or **(my call)**.

## 1. Why
- The iPhone app is sideloaded with a free Apple ID and must be re-signed over USB every
  7 days (iloader; SideStore sign-in is broken by Apple). The maintainer's main pain is
  that weekly refresh. A web app opened from the iPhone's Home Screen never expires.
- It's **for every Taskwise user**, not only the maintainer: one public web address,
  hosted by the maintainer on Vercel, that works with anyone's own Taskwise server.
- It's also usable from any computer or phone browser (Android, desktop), not only the
  iPhone.

## 2. Goals
1. **A copy of the app** in the browser: same functions, same look. Only two designs on
   the web: **Brutal** (default) and **Lapis**, each with **light and dark** (and "System").
2. **A public home page** first (what Taskwise is, download links for Windows, Linux,
   Android, iPhone, and "Open Taskwise in the browser"), then the app.
3. **The app asks for a server address**, then sign in (username + password) or account
   setup, exactly like the native apps' sign-in. It becomes **one more device** (type
   `web`): its own local database in the browser (works offline), syncs through the same
   sync API, appears in Settings → Devices, can be a "Notify on" target.
4. **Time reminders on the web** through Web Push, sent by each user's own server **at the
   reminder's own time**, with nothing running every minute (the maintainer's idea).
5. Everything on **Vercel** (the maintainer's choice "for now"): the web app/home page as
   one Vercel project, each user's sync server as today.

## 3. Non-goals
- Location reminders firing on the web (browsers get no background location). Places and
  location reminders can still be created and edited on the web; phones fire them.
- Siri / Android shortcuts on the web. Background sync on the web (browsers don't allow
  it; the app syncs while open, like the iPhone app between background runs).
- The other two designs (Classic, Slate & Indigo) on the web.
- In-app updates on the web (the browser always loads the newest deployed version).
- Replacing the native iPhone app: it stays, for people who want location reminders/Siri.

## 4. Anti-goals (would be a failure even if it "works")
- A web app that looks or behaves like a different, lesser app.
- Reminders that silently don't arrive. If push isn't possible (iPhone not on the Home
  Screen, permission denied, server not set up for push), the app must say so.
- Breaking or slowing the native apps, or changing the sync protocol incompatibly
  (devices on 1.2.x must keep syncing).
- Anything that stores or logs task titles, notes or passwords outside the user's own
  server and browser (the public site must never see user data).

## 5. Constraints and facts (checked 2026-11-27)
- Flutter web: Safari gets the JavaScript + CanvasKit build by default; the WASM build is
  off by default on WebKit. Flutter is phasing out its built-in service worker, so we write
  our own (needed for push and offline loading).
- drift on the web is stable (WASM sqlite). The fast storage (OPFS) needs the page to be
  cross-origin isolated (`COOP`/`COEP` headers, settable in `vercel.json`); otherwise it
  falls back to IndexedDB. Needs `sqlite3.wasm` and drift's worker in `app/web/`.
- Package support on web: drift_flutter, flutter_secure_storage (browser storage, weaker
  than a keychain), flutter_map, file_selector, url_launcher, cryptography, http,
  flutter_timezone are fine. path_provider, window_manager, tray_manager,
  launch_at_startup don't support web; workmanager is useless there;
  flutter_local_notifications on web shows only immediate notifications. About 18 app
  files import `dart:io` and need guards or web versions.
- iPhone Web Push: only for a site added to the Home Screen (iOS 16.4+), permission asked
  from a user tap; no Apple account needed. Notification action buttons aren't shown on
  iOS. Since iOS 26 any Home Screen site opens as a web app. Home Screen web apps aren't
  subject to Safari's 7-day storage deletion; call `navigator.storage.persist()`.
- Vercel Hobby: cron at most daily (±59 min); functions max 300 s. **Vercel Queues** (beta,
  all plans, first 1,000,000 operations): `send(topic, payload, { delaySeconds })`,
  delay 0 s–7 days (capped by the message's retention, max 7 days), no documented jitter,
  no cancel. **Vercel Schedules** (beta): one-time schedules, but on Hobby each run
  starts up to 15 minutes late, 500 created per billing period.
- The sync server is a generic record store that doesn't interpret records. Due dates are
  stored as a floating local date + minutes (no time zone); reminders follow repeats and
  snoozes; the planner (`planNotifications` in `shared/lib/src/logic/reminder_schedule.dart`)
  is Dart. The server also runs on Docker/Node (self-hosting), where Vercel Queues don't
  exist.

## 6. Approaches

### 6.1 The web app
1. **Flutter web build of the existing app (chosen).** The only way to be "a copy, same
   look" without writing the UI twice. Costs the porting of `dart:io` code and web
   database setup.
2. A small separate web page (TypeScript or Dart without Flutter): fast and light, but a
   different app with a different look, and repeat/reminder logic would be duplicated.
   Ruled out by goal 1.
3. Paid Apple account + TestFlight ($99/year): keeps the native app without the weekly
   refresh, but not for other users without the same cost, and not for non-iPhone
   browsers. Not chosen; still possible later.

### 6.2 Where it lives
1. **One public site that asks for the server (chosen by the maintainer):** home page +
   app on its own Vercel project; works with any Taskwise server. Needs CORS on the server.
2. Served by each sync server (same address): no CORS, but every user hosts the web app
   and there's no public home page. Not chosen. (Self-hosters may still deploy their own
   copy of the site; the docs say how.)

### 6.3 What wakes the server for a reminder
1. **Vercel Queues delayed messages (chosen):** one message per upcoming reminder, sent
   with `delaySeconds` up to 7 days ahead; on time; no extra accounts. On delivery the
   server checks the reminder is still current (messages can't be cancelled).
2. Vercel Schedules one-time schedules: matches the idea too, but up to 15 min late on
   Hobby and 500 per period. Kept as the documented fallback if Queues misbehave.
3. An outside every-minute trigger (cron-job.org, Cloudflare Worker): on time, but an
   extra account for every user. Not chosen.
4. The maintainer's "hourly wake to sync" isn't needed: the server holds all data, so it
   needs no sync to send a reminder.

### 6.4 Who works out the reminder times
1. **The apps compute and upload a "push plan" per web device (my call).** Every app
   already has the Dart planner, the time zones, repeats and snoozes right. The server
   only stores the plan and sends what's due.
2. The server computes the plan: needs the planner ported to TypeScript (repeats,
   projected occurrences, snoozes, daylight saving, floating local times) or Dart compiled
   to JS inside the server. Risky or awkward. Not chosen.

## 7. Design

### 7.1 Site layout and hosting
- New Vercel project serving static files: the **home page** at `/` (plain HTML/CSS,
  light and dark, English and Arabic, links to the latest GitHub release's files) and the
  **Flutter web app** at `/app/`. **(builder's call:** paths, the exact page copy, and
  whether the home page lives in `web/home/` or similar.**)**
- Built in GitHub Actions (pinned Flutter, `flutter build web --base-href /app/`) and
  deployed with the Vercel CLI (`vercel deploy --prebuilt --prod`) when a release is
  **published** (`release: published`), not on the tag: tags only make drafts the
  maintainer tests first, and installed apps also only see published releases. So the web
  app, the home page's download links and the native updates move together. A manual
  "deploy now" (`workflow_dispatch`) is there for fixes to the home page. **(my call)** Needs GitHub secrets for a Vercel token
  and the project/org ids; the maintainer creates them (private secret box, step-by-step).
  **(my call;** Vercel's own build can't easily install Flutter.**)**
- `vercel.json` of the site: `COOP: same-origin`, `COEP: credentialless` (so OSM map
  tiles and the user's server still load) for `/app/*`; long cache for hashed files,
  no-cache for `index.html`, `flutter_bootstrap.js`, the service worker and the manifest.
- PWA bits: web manifest (name, icons, `display: standalone`, theme colours per design),
  `apple-touch-icon`, iPhone safe areas.
- Our own service worker: caches the app shell for offline start, handles `push` and
  `notificationclick`, and tells the page when a new version is waiting ("New version,
  reload").

### 7.2 Sign-in
- First run of `/app/`: the existing sign-in screen with an empty **server address**
  field (validated with `/health`), then username + password, or account setup with the
  setup secret, as on the native apps. `?server=<url>` in the address pre-fills it
  (for self-hosters' links). **(my call)**
- The device registers as type `web`, named e.g. "Safari on iPhone" / "Chrome on Windows"
  (editable). `DeviceType.web` is added in shared and the server; older apps show unknown
  types as "other", which already works.
- Token kept with flutter_secure_storage's web storage. Settings → About notes that on a
  shared computer you should sign out.
- Signed out, the web app is a normal local-only Taskwise in that browser, like the
  native apps. **(my call)**

- **iPhone, Safari tab vs Home Screen (my call):** a Safari tab and the Home Screen app
  keep separate storage on iOS. Opened in a Safari tab on an iPhone (not standalone),
  `/app/` first shows a short "Add Taskwise to your Home Screen" guide (Share → Add to
  Home Screen), with "Continue in Safari anyway" below it. So most people sign in once, in
  the Home Screen app. A leftover Safari device is harmless (no push subscription means
  no notifications are sent to it) and can be removed in Settings → Devices as today.

### 7.3 The web app itself
- Same code base (`app/`), `kIsWeb` guards and web implementations behind conditional
  imports, never scattered `if (kIsWeb)` in screens where a small service interface fits.
- Off on the web: tray/window/start on login (`desktop/`), the updater (`update/`),
  Siri/Android assistant (`assistant/`), workmanager background sync, native location
  engines (location reminders still editable), file paths (`path_provider`).
- Web versions: database (drift web), logs (kept in memory + browser storage, still shown
  in View logs; never task titles etc.), backup export (browser download) and import
  (file picker), notifications (§7.4), "sync on open/visible + every minute while open".
- Design picker on the web lists only Brutal and Lapis; a synced/stored choice of another
  design falls back to Brutal. Light/dark/system and Arabic RTL as in the apps.
- Performance: the existing 2,000-task test should run on the web build too; acceptable
  first load on an iPhone over mobile data is the builder's to measure and report.

### 7.4 Reminders through Web Push
**On the web device:**
- Settings → Notifications on the web: "Turn on notifications in this browser". On an
  iPhone not on the Home Screen, it explains "Add to Home Screen first" with the steps.
  Shows clearly when the server isn't set up for push.
- On tap: ask permission, subscribe with the server's VAPID public key
  (`GET /push/key`), send the subscription to the server (`PUT /push/subscription`).
- Tapping a notification opens/focuses the app on that task. Done/Snooze buttons where
  the browser shows them (not iOS) open the app and do it there, like iOS today.
  **(my call:** the service worker can't safely run repeat logic while the app is closed.**)**

**The push plan (computed by apps, §6.4):**
- For each web device: the next **60 days** of planned notifications for that device
  (respecting "Notify on", repeats, the web device's own snoozes), in that device's time
  zone (reported at login and updated by the web device), as UTC fire times + task id +
  stable key + title. **(builder's call:** exact record shape and endpoint.**)**
- Uploaded by the web device whenever it's open and something changed, and by every
  native app after it pushes task/reminder changes and at least once a day while running.
  Snoozes made on the web device are kept in its own part of the plan, which other devices
  don't overwrite.
- 60 days, not 14 **(my call)**, so a web-only user who doesn't open the app for weeks
  still gets reminders (the daily cron queues items as they come within 7 days; cost is
  only plan size). The web app's notification settings show "Reminders planned until
  <date>", and when the plan has less than 7 days left the app says so on next open.
- Stored by the server in its own tables (not in the generic sync records), so older
  devices are unaffected.

**On the server:**
- New: VAPID key pair (env vars; generated once, documented), tables for push
  subscriptions and plan items, endpoints for key/subscription/plan, CORS on all
  endpoints (any origin, `Authorization` + `Content-Type`, no cookies), `web` device type.
- When a plan arrives: for each item due within 7 days that isn't queued yet, send a
  Vercel Queues message with `delaySeconds` to its fire time (remember it's queued).
- On delivery: if the item is still in the device's current plan with the same fire time
  and wasn't sent, send the Web Push (npm `web-push` or equivalent, **builder's call** after
  checking maintenance), mark it sent. Gone subscriptions (404/410) are removed.
- The existing daily cron queues items that came within the 7-day window.
- On Docker/Node (self-hosting without Vercel): an in-process timer does the same job
  every 30 s. One `PushScheduler` interface, two implementations.
- Fallback documented in code/docs: Vercel Schedules (up to 15 min late on Hobby).

### 7.5 Docs
- `docs/self-hosting.md`: CORS is automatic; turning on web reminders (VAPID keys, Vercel
  Queues config), the Docker variant. A new `docs/web-app.md`: using the public site,
  Add to Home Screen on the iPhone, turning on notifications, limits (no location firing,
  no background sync, sign out on shared computers), how to host your own copy.
- README: the web address. SPEC: §1 device table, §3 features, Progress Log.

## 8. Milestones (my call; the maintainer can merge them)
- **M14: Taskwise on the web** — web build of the app, two designs, sign-in with server
  address, `web` device type, CORS, home page, Vercel project + deploy workflow, docs.
  Usable at once; reminders still come from the native apps.
- **M15: Web reminders** — Web Push, push plans from all apps, Vercel Queues + Docker
  scheduler, notification settings on the web, docs.

## 9. The web address
- A free Vercel address, `<project>.vercel.app` (maintainer's choice, 2026-11-27). The
  project name is picked when the maintainer creates it (first choice `taskwise-app`, else
  the nearest free name), and **never contains the maintainer's name** or server.
- Treat it as permanent: a later move to a custom domain means every web user signs in
  and turns notifications on again (browser data belongs to one address). The address is
  kept in one place (a workflow/config value), and the docs/README link to it.

## 10. Left to the builder
- How to split web/native code (conditional imports, file layout).
- Test strategy details: unit tests for the plan builder and server scheduling (with a
  fake queue and fake push), widget tests that run with web guards, `flutter build web`
  in CI, a browser test of sign-in + sync against a local server (Playwright or
  `flutter drive -d chrome`).
- Exact UI copy (EN + AR) in the app's existing tone.

## 11. Separate, already in progress
- Windows self-update fix (release 1.2.1): the update helper never ran when started
  detached, and `Expand-Archive` fails when PowerShell 7's modules are on `PSModulePath`.
  Not part of M14.
