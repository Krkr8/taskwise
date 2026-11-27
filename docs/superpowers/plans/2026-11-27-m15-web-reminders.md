# M15: Web reminders — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Time reminders reach web devices (iPhone Home Screen, Android/desktop browsers) through Web Push, sent by each user's own sync server at the reminder's own time.

**Architecture:** Apps already plan reminders with the Dart planner (`planNotifications` in shared). Every app uploads a **push plan** for each web device: the next 60 days of fire times. The server stores the plans and subscriptions in its own tables and queues one **Vercel Queues** message per item due within 7 days (`delaySeconds`). When a message arrives, the server checks the item is still current and unsent, then sends the Web Push with VAPID. The daily cron queues items that have come within 7 days. On Docker/Node a 30-second in-process timer does the same job. The web app subscribes from Settings, and its service worker shows the notification and opens the task.

**Tech Stack:** shared Dart, Flutter web (`package:web` PushManager), TypeScript/Hono, `@vercel/queue` 0.11.0, `web-push` 4.0.0 (released 2026-11-06; fall back to 3.6.7 if 4.0.0 fails the tests on Node 24), libSQL/Turso.

**Spec:** `docs/superpowers/specs/2026-11-27-web-app-design.md` §7.4 (with §5 facts). Approved by the maintainer on 2026-11-27, together with M14.

## Global Constraints
- Reminders arrive at their time, not "up to 15 min late": Vercel Queues `delaySeconds` (max 7 days, `retentionSeconds` ≥ delay). Messages can't be cancelled, so every delivery re-checks the item.
- Delivery is at-least-once: claim the item atomically (`UPDATE … SET sent_at=? WHERE … AND sent_at IS NULL`) before sending. Never send one item twice.
- The server stays a generic record store for sync. Push data lives in new tables (`push_subscriptions`, `push_items`) and new endpoints under `/api/v1/push/…`. Devices on 1.2.x/1.3.0 keep syncing unchanged.
- Push plan horizon is **60 days**, capped at 500 items per web device.
- iPhone: permission is only requested from a user tap, and every push shows a notification (no silent push).
- Nothing new is logged that contains task titles, notes, tokens, push endpoints or keys.
- VAPID keys come from server env vars `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`. Without them, push is "not set up": `GET /push/key` answers 404 `push_not_configured`, and the app says so.
- Pin new packages exactly. Native behaviour of reminders is unchanged.
- EN + AR for all user-facing text.

## Rulings (my calls, from facts found while planning)
- **Time zones:** `planNotifications` works in the computing device's local time. A device uploads plans only for web devices whose stored IANA time zone equals its own (from `flutter_timezone`). A web device always plans for itself. Different time zones therefore rely on the web device's own uploads (Known issue).
- **No snooze on the web:** iOS shows no notification buttons. Tapping a notification opens the task. Web devices get no snooze items, so no snooze merging is needed.
- **Body text** is rendered in the language of the device that computed the plan, using the same text function as native notifications.
- **Late messages:** an item whose message arrives more than 60 minutes after its fire time is marked sent without pushing (a stale reminder is worse than none). This is logged without the title.
- **Queue consumer:** Vercel's docs show consumers only as their own function files. The consumer is `server/api/push-delivery.ts` (`handleCallback`), with `vercel.json` `functions` → `experimentalTriggers: [{ type: "queue/v2beta", topic: "taskwise-push" }]`. Task 3 checks on a preview deploy that it deploys next to the Hono app. If it can't, Task 3 uses the closest documented alternative and records it.

## Review Focus
1. **An item that's edited or deleted after its message was queued:** the old message finds no matching unsent `(device, key, fire_at)` and sends nothing. Tested in Task 2.
2. **Two devices uploading the same web device's plan at once:** the result is one consistent plan, with no duplicate queue messages for one item. `queued_at` is set only when the item was inserted or its `fire_at` changed. Tested in Task 2.
3. **A subscription the push service reports gone (404/410):** it is deleted. Other subscriptions of the device still get the push, and `pushEnabled` turns false when none remain. Tested in Task 3.
4. **The server isn't configured for push (no VAPID env) or runs an older version:** the web app shows "This server isn't set up for reminders yet", and plan uploads quietly stop (404) without sync errors. Tested in Tasks 4–5.
5. **A web device that never subscribed:** apps don't upload plans for it (`pushEnabled` false), and the Notify-on picker shows "(notifications off)". Tested in Tasks 4–5.

---

### Task 1: Shared: device time zone and push flag; the push plan builder

**Files:**
- Modify: `shared/lib/src/models/device.dart` (`timeZone: String?`, `pushEnabled: bool` default false; both read from JSON when present, written when set)
- Create: `shared/lib/src/logic/push_plan.dart` (exported from `taskwise_shared.dart`)
- Test: `shared/test/logic/push_plan_test.dart`, the existing device model test

**Interfaces:**
- Produces:
  ```dart
  final class PushPlanItem { final String key; final DateTime fireAt /*UTC*/; final String taskId; final String title; final String body; Map<String, Object?> toJson(); factory PushPlanItem.fromJson(Map<String, Object?>); }
  /// Items for one web device: its targeted tasks' reminders in the next [horizon], sorted by fireAt, at most [limit].
  List<PushPlanItem> buildPushPlan({required Iterable<Task> tasks, required Iterable<Reminder> reminders, required bool Function(Task) notifiesDevice, required DateTime now, required String Function(PlannedNotification) body, Duration horizon = const Duration(days: 60), int limit = 500, int allDayMinutes = 9 * 60});
  String pushPlanHash(List<PushPlanItem> items); // stable, order-independent of input order
  ```
  `key` = `'${p.id}'` (the planner's stable id). `fireAt` = `p.fireAt.toUtc()`.

- [ ] **Step 1: Failing tests:**
  - Task due tomorrow 09:00 with a 30-min reminder → one item, `fireAt` 08:30 local in UTC.
  - Task not targeted (`notifiesDevice` false) → none.
  - A daily repeat → one item per day for 60 days, capped by `limit`.
  - A done task → none.
  - `pushPlanHash` equal for the same items, different when a `fireAt` changes.
  - `Device.fromJson` without `timeZone`/`pushEnabled` → null/false (1.3.0 servers); with them → values.
- [ ] **Step 2:** `cd shared && dart test`. Expect FAIL.
- [ ] **Step 3:** Implement, reusing `planNotifications` (no second copy of the rules).
- [ ] **Step 4:** `dart test` green in the 3 time zones as in CI (`TZ=Asia/Baghdad`, `America/New_York`, `Europe/London`).
- [ ] **Step 5:** Commit `M15: push plan builder`.

### Task 2: Server: push tables, endpoints, plan storage and queuing logic

**Files:**
- Modify: `server/src/db/migrations.ts` (append one migration: `ALTER TABLE devices ADD COLUMN time_zone TEXT`; `CREATE TABLE push_subscriptions (endpoint TEXT PRIMARY KEY, device_id TEXT NOT NULL, p256dh TEXT NOT NULL, auth TEXT NOT NULL, created_at INTEGER NOT NULL)`; `CREATE TABLE push_items (device_id TEXT NOT NULL, key TEXT NOT NULL, fire_at INTEGER NOT NULL, task_id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, queued_at INTEGER, sent_at INTEGER, PRIMARY KEY (device_id, key))`; index on `(sent_at, fire_at)`)
- Modify: `server/src/routes/auth.ts` (login accepts optional `timeZone`), `server/src/routes/devices.ts` (PATCH accepts `timeZone`; GET returns `timeZone` and `pushEnabled` = has ≥ 1 subscription), `server/src/devices.ts`, `server/src/context.ts` (`AppDeps` gains `push?: PushDeps`), `server/src/api.ts`, `server/src/routes/cron.ts` (top-up)
- Create: `server/src/push/store.ts` (subscriptions, plan replace, claim), `server/src/push/schedule.ts` (`PushScheduler` interface, `queueDueItems`), `server/src/push/deliver.ts` (`deliverPushItem`), `server/src/routes/push.ts`
- Test: `server/test/push.test.ts`, plus the device/auth tests

**Interfaces:**
- Produces:
  ```ts
  export interface PushScheduler { enqueue(msg: PushMessage, delaySeconds: number): Promise<void>; }
  export interface PushMessage { deviceId: string; key: string; fireAt: number; }
  export interface PushSender { send(sub: PushSubscriptionRow, payload: string): Promise<'ok' | 'gone'>; }
  export interface PushDeps { publicKey: string; scheduler: PushScheduler; sender: PushSender; }
  export async function queueDueItems(db: Client, scheduler: PushScheduler, now: number, deviceId?: string): Promise<number>; // items with fire_at in (now, now+7d], queued_at null → enqueue, set queued_at
  export async function deliverPushItem(db: Client, sender: PushSender, msg: PushMessage, now: number): Promise<'sent' | 'stale' | 'skipped'>;
  ```
- Endpoints (all behind `requireDevice`, documented in `docs/sync-api.md`):
  - `GET /push/key` → `{ publicKey }`, or 404 `push_not_configured`.
  - `PUT /push/subscription` with body `{ endpoint, keys: { p256dh, auth } }` → 204, for the calling device.
  - `DELETE /push/subscription` with body `{ endpoint }` → 204.
  - `PUT /push/plan/:deviceId` with body `{ items: PushPlanItem[] }` (≤ 500) → 204.
    - The target must be a non-revoked device of type `web`, otherwise 404.
    - Replace semantics: unsent items not in the new list are deleted. A new key, or a changed `fire_at`/`title`/`body` resets `queued_at` (and `sent_at` if `fire_at` changed). Then `queueDueItems` runs for that device.
    - Without push configured, 404 `push_not_configured`.
- Push payload JSON: `{ title, body, taskId, key }`.

- [ ] **Step 1: Failing tests (fake scheduler that records messages; fake sender):**
  - Upload of 3 items (1 h, 3 days, 10 days ahead) → 2 messages, with delays of 3600 s and 259200 s.
  - The same upload again → no new messages.
  - Re-upload with one `fire_at` changed → exactly one new message.
  - Re-upload without an item → that item is deleted; delivering its old message → `'skipped'`, no send (Review Focus 1).
  - Two concurrent uploads of the same list → one message per item (Review Focus 2).
  - Delivering twice → one send, then `'skipped'`.
  - Delivering 61 min late → `'stale'`, no send.
  - A plan for a non-web or revoked device → 404.
  - Without `push` deps → `/push/key` 404 `push_not_configured`.
  - Login with `timeZone` → GET /devices shows it; `pushEnabled` follows subscriptions.
  - The daily cron queues an item that is now within 7 days.
  - A 1.2.x-style login (no `timeZone`) still works.
- [ ] **Step 2:** `cd server && npm test`. Expect FAIL.
- [ ] **Step 3:** Implement. The migration test (`migrations.test.ts`) covers upgrade from the last schema.
- [ ] **Step 4:** `npm test` and `npm run typecheck` green.
- [ ] **Step 5:** Commit `M15: push plans and subscriptions on the server`.

### Task 3: Server: Vercel Queues, Web Push sender, Node timer, config

**Files:**
- Modify: `server/package.json` (add `@vercel/queue` 0.11.0 and `web-push` 4.0.0 exactly; `@types/web-push` if needed, pinned), `server/src/config.ts` (VAPID env; push on only when all three are set), `server/src/index.ts` (Vercel: `QueuePushScheduler`), `server/src/node.ts` (Node: `NoopScheduler` + `setInterval` 30 s that runs `sendDuePushes`), `server/vercel.json` (`functions` → `api/push-delivery.ts` `experimentalTriggers` topic `taskwise-push`)
- Create:
  - `server/src/push/vercel_queue.ts`: `send('taskwise-push', msg, { delaySeconds, retentionSeconds: delaySeconds + 3600 capped at 604800, idempotencyKey: \`${deviceId}:${key}:${fireAt}\` })`;
  - `server/src/push/web_push_sender.ts`: VAPID; maps 404/410 to `'gone'`; TTL 3600 s; urgency `high`;
  - `server/src/push/due.ts`: `sendDuePushes(db, sender, now)` for Node, which delivers unsent items with `fire_at <= now`;
  - `server/api/push-delivery.ts`: `handleCallback(async (msg) => deliverPushItem(...))`, opening the db like `src/index.ts`.
- Docs: `docs/self-hosting.md` "Web reminders" section:
  - generate keys with `npx web-push@4.0.0 generate-vapid-keys`;
  - set the 3 env vars on the server project (Vercel → Settings → Environment Variables) and redeploy;
  - `VAPID_SUBJECT` is `mailto:` your email or your site's https URL;
  - Docker: the same env vars; the timer is built in.
- Test: `server/test/push_sender.test.ts` (sender maps status codes; uses a local HTTP endpoint or web-push's request generation without network), `server/test/due.test.ts`

**Interfaces:**
- Consumes: Task 2's interfaces.

- [ ] **Step 1: Failing tests:**
  - The sender returns `'gone'` for 404 and 410 and `'ok'` for 201.
  - A `'gone'` result deletes that subscription, and other subscriptions of the device still receive it (Review Focus 3).
  - `sendDuePushes` sends a due item once, and the next tick sends nothing.
  - Config without one of the VAPID vars → push off.
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `npm test`, `npm run typecheck`, `npm run build` green.
- [ ] **Step 5 (controller):** Push the branch, which makes a Vercel **preview** deploy of the server project. Confirm the deploy succeeds and the `api/push-delivery` function exists next to the Hono app. With preview env vars (VAPID + a scratch Turso database, set by the controller through the Vercel API), queue a test item 2 minutes ahead. Check that the consumer ran on time: the function log shows delivered/skipped, with no titles. Record the result. If the consumer can't live there, apply the documented alternative and repeat.
- [ ] **Step 6:** Commit `M15: Vercel Queues and Web Push delivery`.

### Task 4: App: upload push plans from every device

**Files:**
- Modify: `app/lib/sync/sync_api.dart` (`pushKey()`, `putPushSubscription(...)`, `deletePushSubscription(endpoint)`, `putPushPlan(deviceId, items)`; `login(..., timeZone)`; `updateDeviceTimeZone`), `app/lib/sync/sync_controller.dart` (send the time zone at login and when it changes)
- Create: `app/lib/notifications/push_plan_uploader.dart`
  - Watches tasks, reminders, targets, devices and settings like `ReminderScheduler`, debounced 5 s, after each successful sync, and every 24 h.
  - For each non-revoked web device with `pushEnabled` (and for this device itself when it's a web device with a subscription) whose `timeZone` equals this device's, builds `buildPushPlan`.
  - Uploads only when `pushPlanHash` differs from the last upload for that device (kept in memory and in a device-only setting).
  - A 404 `push_not_configured` stops uploads until the next app start.
- Extract the native notification body text function from `reminder_scheduler.dart` into a function both use (no behaviour change).
- Test: `app/test/notifications/push_plan_uploader_test.dart`

- [ ] **Step 1: Failing tests (fake API):**
  - A web device with `pushEnabled` in the same time zone → one upload with the expected items.
  - Unchanged data → no second upload.
  - A task edit → a new upload.
  - A web device without `pushEnabled` or in another time zone → no upload (Review Focus 5).
  - A server answering `push_not_configured` → uploads stop, sync status unaffected (Review Focus 4).
  - Native reminder scheduling unchanged (existing tests green).
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement. Start the uploader where `ReminderScheduler` starts.
- [ ] **Step 4:** `cd app && flutter analyze && flutter test` green.
- [ ] **Step 5:** Commit `M15: apps upload push plans for web devices`.

### Task 5: Web app: turn on notifications, service worker push, open the task

**Files:**
- Create: `app/lib/platform/web_push.dart`, a conditional import. `abstract class WebPushClient { Future<WebPushSupport> support(); Future<String> permission(); Future<WebPushSubscription?> subscribe(String vapidPublicKey); Future<void> unsubscribe(); }` with `enum WebPushSupport { supported, needsHomeScreen, unsupported }`. iOS + not standalone → `needsHomeScreen`. The web implementation uses `navigator.serviceWorker.ready` → `pushManager.subscribe({userVisibleOnly: true, applicationServerKey})`.
- Create: `app/lib/ui/shared/settings/web_notifications_section.dart`. Its states, all EN + AR:
  - not supported: "This browser can't show notifications."
  - `needsHomeScreen`: "Add Taskwise to your Home Screen first, then turn on notifications there." with a button to the guide.
  - server not set up: "This server isn't set up for reminders yet." with a link to `docs/self-hosting.md#web-reminders`.
  - denied: "Notifications are blocked for this site. Allow them in the browser's settings."
  - off: button **Turn on notifications in this browser**. On tap: permission, then subscribe, then `PUT /push/subscription`, then plan upload now.
  - on: "Notifications are on in this browser." and "Reminders planned until <date>" (the last plan item, or "No upcoming reminders"), with **Turn off**.
- Modify:
  - Brutal and Lapis settings pages: the section replaces the M14 "Reminders don't ring in the browser yet…" note on the web.
  - `app/lib/ui/shared/tasks/device_targets_editor.dart`: web devices show "(notifications off)" when `!pushEnabled`; the M14 "(no reminders yet)" text goes.
  - `homeScreenGuideWhy`: can say the Home Screen app gets reminders again.
  - `app/web/sw.js`:
    - `push`: always `showNotification(title, { body, tag: key, data: { taskId }, icon: 'icons/Icon-192.png' })`; a malformed payload still shows a generic "Taskwise reminder".
    - `notificationclick`: focus an open client and `postMessage({type: 'open-task', taskId})`, or `openWindow('./#task=<id>')`.
  - `app/web/index.html` / `web_shell.dart`: `#task=<id>` and `open-task` messages call `openTaskRequestProvider.request(id)`.
- Docs: `docs/web-app.md` (turning on reminders, iPhone Home Screen requirement, limits).
- Test: `app/test/settings/web_notifications_section_test.dart` (fake client and API: each state's text; the turn-on flow calls the API in order; denied shows the blocked text). Extend the browser smoke test: use CDP `ServiceWorker.deliverPushMessage` to deliver a payload to the app's service worker, then assert a notification was shown (`registration.getNotifications()`) with the title, and that clicking it opens the task. Also extend `web/test_site_browser.mjs` if that's simpler.

- [ ] **Step 1:** Failing widget tests.
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `flutter analyze`, `flutter test`, the browser smoke test and the site check green.
- [ ] **Step 5:** Commit `M15: notifications in the web app`.

### Task 6: Docs, version 1.4.0, release

**Files:**
- `SPEC.md`: §3.10 Web reminders; Progress Log M15 row, Where we left off, Known issues (different time zones, iPhone Home Screen only, no snooze on the web).
- `CHANGELOG.md`: `1.4.0`.
- `app/pubspec.yaml` → `1.4.0+17`; `app/lib/version.dart`.
- `docs/architecture.md`: the push path.

- [ ] **Step 1:** Write docs and bump the version.
- [ ] **Step 2:** Full verification: app, shared (3 time zones), server, web build, site check, browser smoke test, Linux build. All green.
- [ ] **Step 3 (controller):**
  1. Generate VAPID keys locally; the private key stays only in `~/.config/taskwise/server-secrets.env`.
  2. Set the 3 env vars on the production server project through the Vercel API.
  3. Merge to main, which deploys the server.
  4. Check `GET /api/v1/push/key` answers.
  5. Tag `v1.4.0`.
- [ ] **Step 4:** Give the maintainer beginner-friendly test steps for: iPhone Home Screen app → Settings → Turn on notifications → a reminder 3 minutes ahead, with the app closed; a desktop browser; a reminder added on the PC reaching the iPhone web app.
