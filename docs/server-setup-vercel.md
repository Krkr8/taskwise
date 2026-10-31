# Set up the sync server on Vercel

The sync server keeps your devices in step. It runs for free on **Vercel**, with its data in a free **Turso** database. Both are fully managed, so there is nothing to update or secure yourself. Everything below is done in a web browser plus a few terminal commands on the Fedora laptop, and takes about 20 minutes.

You will end up with an address like `https://taskwise-abc.vercel.app`. You type that address into the app when you set up sync (M6).

**Free limits** (checked 2026-10-31):

| Service | Free allowance | What Taskwise uses |
|---|---|---|
| Vercel Hobby | 1,000,000 requests a month, cron once a day | About 45,000 a month with 3 devices syncing every minute for 8 hours a day |
| Turso Free | 5 GB storage, 500 M rows read and 10 M rows written a month | A few MB and a tiny fraction of the rows |

Vercel's Hobby plan is for **personal, non-commercial use**, which is what this is. If a limit is ever exceeded, Vercel pauses that feature for up to 30 days. That is very unlikely here. Check the usage pages in both dashboards if you're curious.

## 1. Make three secrets

On the laptop, run:

```bash
echo "SETUP_SECRET=$(openssl rand -base64 32)"
echo "CRON_SECRET=$(openssl rand -hex 32)"
```

Save both lines in your password manager.

- The **setup secret** is needed once, to create your account. Without it, anyone who found the server address could claim the account first.
- The **cron secret** lets only Vercel run the daily clean-up and backup.

The third secret, the database token, comes in the next step.

## 2. Create the database on Turso

1. Go to <https://turso.tech> and **Sign up** (signing in with GitHub is easiest). No credit card is needed.
2. In the dashboard, create a **database**. Name it `taskwise` and pick a **location close to you**. Remember the location: Vercel should run in the same area (step 3.6). Europe is a good choice from Iraq.
3. Open the database and copy its **URL**. It looks like `libsql://taskwise-<your-org>.turso.io`.
4. Create a **token** for the database (read and write, no expiry) and copy it. This is `DATABASE_AUTH_TOKEN`. Turso shows it only once, so save it in your password manager as well.

The server creates its own tables on the first request, so there is nothing else to set up in Turso.

## 3. Deploy on Vercel

1. Go to <https://vercel.com/signup> and sign up for the **Hobby** plan with **Continue with GitHub**.
2. Click **Add New… → Project**. Under **Import Git Repository**, find `taskwise`. If it isn't listed, click **Adjust GitHub App Permissions** and give Vercel access to the `taskwise` repository.
3. Click **Import**. On the configuration page:
   - **Root Directory:** click **Edit** and choose `server`. This is important.
   - **Framework Preset:** Vercel should detect **Hono**. Leave the build settings as they are.
   - **Environment Variables:** add these four (name → value):

     | Name | Value |
     |---|---|
     | `DATABASE_URL` | the Turso URL from step 2.3 |
     | `DATABASE_AUTH_TOKEN` | the Turso token from step 2.4 |
     | `SETUP_SECRET` | from step 1 (only the part after `SETUP_SECRET=`) |
     | `CRON_SECRET` | from step 1 (only the part after `CRON_SECRET=`) |

4. Click **Deploy** and wait for the confetti.
5. Click **Continue to Dashboard**. Under **Domains** you see your address, for example `taskwise-abc.vercel.app`.
6. **Region:** open **Settings → Functions** and set the **Function Region** to the one closest to your Turso database (for example Frankfurt for a Turso database in Frankfurt), then **Save**. Every request makes a few database round trips, so keeping the two close makes sync noticeably faster. A new region only applies to new deployments: open **Deployments**, click **⋯** on the top one, and choose **Redeploy**.

From now on, every push to `main` on GitHub redeploys the server automatically, and you don't need to do anything.

## 4. Check it works

On the laptop, replace the address with yours:

```bash
curl https://taskwise-abc.vercel.app/api/v1/health
```

You should see:

```json
{"status":"ok","apiVersion":1,"time":"2026-10-31T12:00:00.000Z"}
```

On the iPhone, **switch Wi-Fi off** (so it uses mobile data), open Safari, and go to the same address: `https://taskwise-abc.vercel.app/api/v1/health`. The same text should appear.

If you see `"status":"error"`, the server can't reach the database. Check `DATABASE_URL` and `DATABASE_AUTH_TOKEN` under **Settings → Environment Variables**, fix them, then **Redeploy** (step 3.6). The **Logs** tab in Vercel shows what went wrong.

## 5. Create your account (optional now)

From M6 the app has a setup page for this. You can also do it now from the laptop. Choose a username and a password of at least 10 characters:

```bash
curl -X POST https://taskwise-abc.vercel.app/api/v1/auth/setup \
  -H 'Content-Type: application/json' \
  -d '{"setupSecret": "PASTE-SETUP-SECRET", "username": "me", "password": "PASTE-A-LONG-PASSWORD"}'
```

The reply `{"username":"me"}` means it worked. Running it again gives `"The account already exists."`. The setup secret is not needed after this.

## Changing secrets later

- **Cron secret or setup secret:** change the value in **Settings → Environment Variables**, then **Redeploy**.
- **Database token:** create a new token in Turso, revoke the old one there, put the new one in Vercel, then **Redeploy**.
- **A lost or stolen device:** revoke it in the app under **Settings → Devices** (M6). It can't sync again until someone logs in on it with your password.

## Backups

- Turso keeps 1 day of point-in-time restore on the free plan.
- Every night the server also saves a full copy of your data in the database's `backups` table, keeping the last 7. To look at them, open the database in the Turso dashboard and use its SQL shell to run `SELECT id, created_at FROM backups`.
- Every device holds a full copy of your data too (the app is local-first), and JSON export comes in M8.

## Self-hosting with Docker (instead of Vercel)

The same server runs as a normal Node.js server, for anyone who prefers their own machine. With Docker or Podman, run these from the repository root:

```bash
docker build -t taskwise-server server
docker run -d --name taskwise -p 8787:8787 -v taskwise-data:/data \
  -e SETUP_SECRET="$(openssl rand -base64 32)" \
  -e CRON_SECRET="$(openssl rand -hex 32)" \
  taskwise-server
curl http://localhost:8787/api/v1/health
```

- The data lives in a SQLite file in the `taskwise-data` volume. To use Turso instead, set `DATABASE_URL` and `DATABASE_AUTH_TOKEN` with `-e`.
- Run `docker inspect taskwise` to read back the generated secrets.
- Put the server behind an HTTPS reverse proxy (for example Caddy). The proxy must set `X-Forwarded-For`, because the login rate limit uses it.
- Nothing calls the daily job for you here. Add a daily cron entry on the host:
  ```
  0 3 * * * curl -fsS -H "Authorization: Bearer <CRON_SECRET>" http://localhost:8787/api/v1/cron/daily
  ```

## Running the server locally (for development)

You need Node.js 24 (see [dev-setup-fedora.md](dev-setup-fedora.md)).

```bash
cd server
npm ci
cp .env.example .env      # local SQLite file; fill in SETUP_SECRET to try setup
npm run dev               # http://localhost:8787/api/v1/health
npm test                  # type-check with `npm run typecheck`
```

The API is documented in [sync-api.md](sync-api.md).
