# Host your own Taskwise sync server

Taskwise works without a server. A sync server keeps your devices in step: a task you add on the laptop shows up on the phone. The server is yours: you create the one account, and your data stays in your own database.

There are two ways to run it. Pick one.

| | A. Vercel + Turso | B. Docker or Node.js |
|---|---|---|
| Cost | Free | Free, if you already have a machine that is always on |
| You look after | Nothing | The machine, updates, HTTPS and backups |
| Best for | Most people | People who already run their own server |
| Time | About 20 minutes | About 20 minutes |

In both cases the app finds the server through one address (for example `https://taskwise.example.com`). You type it in the app under **Settings → Sync → Connect to your server**.

Everything below uses placeholders like `PASTE-SETUP-SECRET`. **Never share your real secrets, and never put them in a file in the repository.**

## What the server needs

The server reads four settings from environment variables:

| Name | Required | What it is |
|---|---|---|
| `DATABASE_URL` | Yes | Where the data is kept. `libsql://<db>-<org>.turso.io` for Turso, or `file:/path/to/taskwise.db` for a file on your machine. |
| `DATABASE_AUTH_TOKEN` | Only for Turso | The Turso token. Leave it out for a local file. |
| `SETUP_SECRET` | Yes, to create the account | A long random secret you type once when you create your account. Without it, anyone who finds the address could claim the account first. Setup is refused once an account exists. |
| `CRON_SECRET` | Yes, for the daily job | A long random secret that lets only you (or Vercel) run the daily clean-up and backup. |
| `PORT` | No | The port of the plain Node server. Default `8787`. Not used on Vercel. |

The server creates its tables by itself on the first request.

Make the two secrets like this, and keep them in a password manager:

```bash
echo "SETUP_SECRET=$(openssl rand -base64 32)"
echo "CRON_SECRET=$(openssl rand -hex 32)"
```

---

## A. Vercel + Turso (free, nothing to maintain)

Vercel runs the server code and Turso keeps the data. Both have a free plan that is plenty for one person (checked on 2026-10-31: about 45,000 requests a month with three devices, against a limit of 1,000,000).

In short:

1. Make the two secrets (above).
2. On [turso.tech](https://turso.tech), create a database called `taskwise` close to you. Copy its URL (`DATABASE_URL`) and make a token for it (`DATABASE_AUTH_TOKEN`).
3. On [vercel.com](https://vercel.com), import your copy (fork) of the repository. Set **Root Directory** to `server` and add the four environment variables.
4. Deploy, then set the Vercel function region close to your Turso database.
5. Check `https://<your-app>.vercel.app/api/v1/health`.

Every click and command is in **[server-setup-vercel.md](server-setup-vercel.md)**. It also explains how to create your account, change secrets later and look at the backups. Vercel runs the daily job for you (`server/vercel.json`).

---

## B. Docker or plain Node.js on your own machine

Use this if you have a computer or a small VPS that is always on.

You need either Docker (or Podman) or Node.js 24, a way to reach the machine from your devices, and a domain name for HTTPS (see "HTTPS" below).

### 1. Put the secrets in a file

Make a file outside the repository, readable only by you:

```bash
printf 'SETUP_SECRET=%s\nCRON_SECRET=%s\n' "$(openssl rand -base64 32)" "$(openssl rand -hex 32)" > ~/taskwise-server.env
chmod 600 ~/taskwise-server.env
```

Open the file once to copy the two values into your password manager. The examples below use this file.

### 2a. With Docker (or Podman)

From the repository root:

```bash
docker build -t taskwise-server server
docker run -d --name taskwise --restart unless-stopped \
  -p 127.0.0.1:8787:8787 \
  -v taskwise-data:/data \
  --env-file ~/taskwise-server.env \
  taskwise-server
curl http://localhost:8787/api/v1/health
```

You should see `{"status":"ok","apiVersion":1,...}`.

- The data is a SQLite file in the `taskwise-data` volume (`/data/taskwise.db`). The image sets `DATABASE_URL` for you.
- `-p 127.0.0.1:8787:8787` makes the server reachable only from the machine itself. The reverse proxy (below) is the only way in from outside. Use `-p 8787:8787` only if you really want direct access.
- To use Turso instead of the file, add `DATABASE_URL=libsql://...` and `DATABASE_AUTH_TOKEN=...` to the env file. The volume is then not needed.
- With Podman, use `podman` instead of `docker`.

### 2b. With plain Node.js

You need Node.js 24 (see [dev-setup-fedora.md](dev-setup-fedora.md), step 3). From the repository root:

```bash
cd server
npm ci
npm run build
echo 'DATABASE_URL=file:/var/lib/taskwise/taskwise.db' >> ~/taskwise-server.env
node --env-file="$HOME/taskwise-server.env" dist/node.js
```

Make the folder for the database first (`sudo mkdir -p /var/lib/taskwise && sudo chown "$USER" /var/lib/taskwise`), or pick another path. `npm start` also works (it runs `node dist/node.js`), but it does not read an env file, so set the variables in your shell first.

To keep it running after you log out, use a service manager. A minimal systemd unit, saved as `/etc/systemd/system/taskwise.service` (change `youruser` and the paths):

```ini
[Unit]
Description=Taskwise sync server
After=network.target

[Service]
User=youruser
WorkingDirectory=/home/youruser/taskwise/server
ExecStart=/usr/bin/node --env-file=/home/youruser/taskwise-server.env dist/node.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Then `sudo systemctl daemon-reload && sudo systemctl enable --now taskwise`. Check `node` is at `/usr/bin/node` with `which node`, and fix the path if it isn't.

### 3. HTTPS

The app sends your password and a login token to the server, so the server must be reached over **HTTPS**. The Taskwise server speaks plain HTTP, so put a **reverse proxy** in front of it. [Caddy](https://caddyserver.com) is the easiest, because it gets and renews a free certificate by itself. You need a domain name that points to your machine (here `taskwise.example.com`), and ports 80 and 443 open. A `Caddyfile`:

```
taskwise.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

Start Caddy (`sudo systemctl enable --now caddy`) and check:

```bash
curl https://taskwise.example.com/api/v1/health
```

Any other proxy (nginx, Traefik) works too. It must pass the real client address in an `X-Forwarded-For` header. Caddy does this by default.

**Why the proxy matters for security.** The login rate limit counts failed attempts per username and per client address, and it reads the address from `X-Forwarded-For`. Anyone who reaches the server directly can put any value in that header, so the per-address limit only works when a proxy you control sets it. Only the per-username limit is reliable without one. So: let the proxy be the only way in (that is why the Docker example listens on `127.0.0.1`), and keep the account password long.

### 4. Create your account

You do this once. Choose a username and a password of at least 10 characters. In the app: **Settings → Sync → Connect to your server → First time? Create the account**. Or from a terminal:

```bash
curl -X POST https://taskwise.example.com/api/v1/auth/setup \
  -H 'Content-Type: application/json' \
  -d '{"setupSecret": "PASTE-SETUP-SECRET", "username": "me", "password": "PASTE-A-LONG-PASSWORD"}'
```

The reply `{"username":"me"}` means it worked. A second try says the account already exists. After this, `SETUP_SECRET` is not needed any more.

### 5. The daily job

Once a day the server deletes old deleted records (older than 90 days), deletes old login attempts and saves a copy of all data (it keeps the last 7). On Vercel this runs by itself. On your own machine you have to call it. Add a line to your crontab (`crontab -e`), with your real cron secret:

```
0 3 * * * curl -fsS -H "Authorization: Bearer PASTE-CRON-SECRET" http://localhost:8787/api/v1/cron/daily
```

The server runs fine without it, but its database grows slowly and the nightly copy is not made.

### Backups

You have several safety nets. Use more than one.

- **Your devices.** Every device keeps a full copy of your data, because Taskwise is local-first. If the server is lost, sign in to a new server from a device and the data is uploaded again.
- **The nightly copy.** The daily job (above) saves all records in the `backups` table of the same database.
- **A copy of the database.** This is the one that survives losing the machine. For the Docker setup, stop the server for a moment, copy the files, and start it again:
  ```bash
  docker stop taskwise
  docker run --rm -v taskwise-data:/data -v "$PWD":/backup alpine sh -c 'cp /data/taskwise.db* /backup/'
  docker start taskwise
  ```
  On Fedora (and other systems with SELinux), write `-v "$PWD":/backup:Z` instead, or the copy is refused with "Permission denied".

  For plain Node, stop the service and copy `taskwise.db` (and any `taskwise.db-wal` and `taskwise.db-shm` next to it). Store the copy somewhere else, such as another machine.
- **JSON export.** Settings → Backup in the app exports all your data to a JSON file, and imports it again.

### Update the server

```bash
cd taskwise
git pull
docker build -t taskwise-server server
docker stop taskwise && docker rm taskwise
# then run the "docker run" command from step 2a again
```

The data stays in the `taskwise-data` volume. For plain Node, run `git pull`, `npm ci` and `npm run build` in `server/`, then restart the service. The server upgrades its database tables by itself.

---

## Connect the app

On each device: **Settings → Sync → Connect to your server**. Enter the address (for example `https://taskwise.example.com` or `https://<your-app>.vercel.app`), your username and password, and a name for the device. The first device to connect becomes the **main device**, which can rename and remove the others. Tasks that are already on the device are uploaded and merged.

## If something goes wrong

- **`/api/v1/health` shows `"status":"error"`:** the server can't reach its database. Check `DATABASE_URL` (and `DATABASE_AUTH_TOKEN` for Turso). Docker: `docker logs taskwise`. Node: the terminal or `journalctl -u taskwise`. Vercel: the **Logs** tab.
- **The app says it can't connect:** open the address in a browser followed by `/api/v1/health`. If that works there but not in the app, check you typed `https://` and have no space or slash at the end.
- **"The account already exists":** setup works only once. Sign in instead.
- **Changing a secret:** change it in the env file (or in Vercel's settings) and restart the server (or redeploy).

The API itself is described in [sync-api.md](sync-api.md).
