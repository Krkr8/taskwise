# Taskwise sync API (v1)

The contract between the Taskwise app and its sync server (`server/`). The examples in [`shared/test/fixtures/sync/`](../shared/test/fixtures/sync/) are the source of truth for the JSON shapes. Both sides test against them:

- the server replays `flow.json` against itself (`server/test/contract.test.ts`);
- the app's shared models check that every record and device in it round-trips through `fromJson`/`toJson` (`shared/test/sync_fixtures_test.dart`).

If you change the API, change the fixtures first. Then both test suites tell you what else has to change.

## Basics

- Base path: `/api/v1` (`AppInfo.apiBasePath` in shared). Example: `https://<app>.vercel.app/api/v1/health`.
- JSON in, JSON out. Send `Content-Type: application/json` with bodies. Request bodies are limited to 1 MiB.
- Times are UTC ISO 8601 strings ending in `Z`, e.g. `2026-10-31T12:00:00.000Z`.
- **Auth:** every endpoint except `/health`, `/auth/setup`, `/auth/login` and `/cron/daily` needs a device token:
  `Authorization: Bearer tw_…`
- **Errors** always look like this, with one of the codes below:
  ```json
  { "error": { "code": "bad_request", "message": "changes[3]: unknown type \"device\"." } }
  ```
  The message is for people (logs, debugging). Code against `code`.

| Status | `code` | When |
|---|---|---|
| 400 | `bad_request` | Invalid JSON, a missing or invalid field, a bad query parameter, more than 500 changes in a push |
| 401 | `unauthorized` | Missing, wrong or revoked device token; wrong password; wrong cron secret |
| 403 | `forbidden` | Wrong setup secret; a device that isn't the main one tries to manage other devices |
| 403 | `wrong_password` | `POST /devices/claim-main` with a wrong password (not 401, so the app doesn't take it as "signed out") |
| 404 | `not_found` | Unknown endpoint or device |
| 409 | `conflict` | `/auth/setup` when the account already exists |
| 410 | `resync_required` | `GET /sync` with a `since` older than purged deletions (see [Tombstones](#tombstones-and-purging)) |
| 413 | `payload_too_large` | Body over 1 MiB |
| 429 | `rate_limited` | Too many failed logins; the `Retry-After` header holds the seconds to wait |
| 500 | `not_configured` | `DATABASE_URL` is not set on the server |
| 500 | `internal` | Anything else (details only in the server log) |
| 503 | `not_configured` | `/cron/daily` when `CRON_SECRET` is not set |
| 503 | `setup_disabled` | `/auth/setup` when `SETUP_SECRET` is not set |

## Health

`GET /health` needs no auth. It returns `200` when the server and its database work, and `503` with `"status": "error"` when the database can't be reached:

```json
{ "status": "ok", "apiVersion": 1, "time": "2026-10-31T12:00:00.000Z" }
```

## Account

There is one account. It is created once, and only by someone who knows the server's `SETUP_SECRET` environment variable, because the server is public.

`POST /auth/setup`
```json
{ "setupSecret": "…", "username": "owner", "password": "at least 10 characters" }
```
- `201 {"username": "owner"}` on success.
- `403` for a wrong secret, `409` if the account already exists, and `503` if `SETUP_SECRET` isn't set.

The password is stored as an argon2id hash.

## Login and devices

Each app install is a **device**. Logging in registers the device and returns its token:

`POST /auth/login`
```json
{
  "username": "owner",
  "password": "…",
  "device": { "id": "0199a3c0-…", "name": "Fedora Laptop", "type": "linux" }
}
```
- `device.id` is a UUID that the app makes once and keeps.
- `type` is one of `windows`, `linux`, `ios`, `other`.

The reply:
```json
{ "token": "tw_…", "device": { "id": "0199a3c0-…", "name": "Fedora Laptop", "type": "linux",
  "lastSeenAt": "…", "updatedAt": "…", "deleted": false, "updatedByDevice": null, "main": true } }
```

- Store the token securely (`flutter_secure_storage`). The server keeps only its SHA-256 hash, so it can't be shown again.
- Logging in again with the same device id replaces the token, and the old one stops working. It also re-activates a revoked device.
- **Rate limit:** 5 failed logins within 15 minutes, per client IP or per username, block further attempts with `429` until the 15-minute window ends. A successful login clears the count.

The `device` objects match the shared `Device` model.

**The main device** (`"main": true`) manages the account's devices (owner's request, 2026-11-02):
- The first device to sign in becomes the main device. If there is no active main device, the next one to sign in becomes it.
- Only the main device can remove other devices, rename other devices, and pass the role to another device.
- Any device can rename itself and sign itself out.
- If the main device signs out or is removed, the most recently seen other device becomes the main one.
- If the main device is lost, any signed-in device can take the role with the account password: `POST /devices/claim-main`.

The endpoints:
- `GET /devices` returns `{"devices": [...]}` with all devices, oldest first. Revoked devices are listed as `"deleted": true`.
- `PATCH /devices/{id}` with `{"name": "Work PC"}` renames a device. With `{"main": true}` it makes that device the main one. The two can be combined. It returns the device.
- `DELETE /devices/{id}` revokes the device's token and returns the device with `"deleted": true`. From then on that device gets `401` everywhere, until it logs in again (it doesn't get the main role back). A device may always revoke itself (sign out).
- `POST /devices/claim-main` with `{"password": "…"}` makes the calling device the main one. A wrong password gets `403 wrong_password`. Failures count towards the same rate limit as logins.

`lastSeenAt` is updated at most once a minute, by any authenticated request.

## Sync

### Records

The server stores records of these types and doesn't look inside them beyond the envelope fields:

| `type` | Shared model | Notes |
|---|---|---|
| `task` | `Task` | |
| `subtask` | `Subtask` | has `taskId` |
| `category` | `Category` | |
| `tag` | `Tag` | |
| `taskTag` | `TaskTag` | has `taskId`, `tagId` |
| `reminder` | `Reminder` | has `taskId` |
| `place` | `Place` | |
| `setting` | (none) | `{id: <setting key>, value: <string>, …}`. Only settings marked synced are pushed. |
| `taskTargetDevice` | `TaskTargetDevice` | has `taskId`, `deviceId` |

Devices are not synced as records; use `/devices`.

Every record has the envelope fields from SPEC.md §4:

| Field | |
|---|---|
| `id` | string, 1–128 characters (UUID v7 for records made by Taskwise); unique per type |
| `updatedAt` | UTC ISO time of the last change, set by the device that made it |
| `deleted` | `true` for a tombstone (a deleted record) |
| `updatedByDevice` | set by the **server** to the pushing device's id; whatever the client sends is ignored |

### Push: `POST /sync`

```json
{ "changes": [ { "type": "task", "record": { "id": "…", "updatedAt": "…", "deleted": false, "title": "Buy milk" } } ] }
```

- Send at most 500 changes per request. Send more in several requests.
- If any change is invalid, the whole push is rejected with `400` and nothing is stored. The message names the bad change, e.g. `changes[3]: …`.
- **Last write wins, per record.** A change replaces the stored record only if its `updatedAt` is later. If the times are equal, the change from the device with the greater device id (compared as strings) wins, so every device agrees on the result.
- A replaced record is stored whole: there is no field-level merge.

The reply has one result per change, in order, and the server's latest sequence number:
```json
{ "results": [ { "type": "task", "id": "…", "status": "applied" },
               { "type": "category", "id": "…", "status": "stale" } ],
  "seq": 11 }
```
- `stale` means the server already has a newer (or the same) version. The client gets the winning version in its next pull.
- Re-sending a push (for example after a timeout) is safe: the repeated changes come back `stale`.

### Pull: `GET /sync?since=<seq>&limit=<n>`

Every stored change gets the next number in a server-wide **change sequence**. A pull returns the records changed after `since`, oldest first, with each record in its latest version:

```json
{ "changes": [ { "type": "task", "seq": 10, "record": { "…": "…" } } ],
  "nextSince": 10, "hasMore": false }
```

- `since` defaults to 0 (everything).
- `limit` defaults to 500, maximum 1000.
- Keep pulling with `since = nextSince` while `hasMore` is true. After a full pull, save `nextSince` for next time.
- The numbers can have gaps (stale pushes use up a number).
- A pull also returns the device's own changes. Applying them again is harmless.

A full sync is: push local changes, then pull until `hasMore` is false.

### Tombstones and purging

Deleting a record means pushing it with `"deleted": true`. A daily job (`GET /cron/daily`) removes:

- tombstones older than 90 days;
- the `subtask`, `reminder`, `taskTag` and `taskTargetDevice` records of those purged tasks (deleted tasks keep their children so undo works);
- expired login counters.

A device whose `since` is older than the purged tombstones would never learn about those deletions. It gets `410 resync_required` and should pull again from `since=0` and drop local synced records the server no longer has.

## Daily job: `GET /cron/daily`

Vercel Cron calls it once a day (03:00 UTC ± 1 h; see `server/vercel.json`) with `Authorization: Bearer <CRON_SECRET>`. Calling it more than once is safe. It purges as described above, then saves a JSON copy of all records in the database's `backups` table, keeping the newest 7.

The reply is `{"purgedRecords": 3, "purgedLoginAttempts": 1, "backupRecords": 120}`.
