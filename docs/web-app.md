# Taskwise in the browser

Taskwise also runs in a web browser: the same app, on any computer or phone, with nothing to install. It is the same code as the Windows, Linux, iPhone and Android apps.

The address of the public site is in the repository's **About** box on GitHub (top right of the project page) <!-- WEB_APP_URL -->. The home page there has the download links for every platform. The app itself is at `/app/` on the same address.

## Use it

1. Open the site and choose **Open Taskwise in the browser**.
2. Taskwise works on its own, in the browser's storage. To share your tasks with your other devices, sign in to your own sync server: **Settings → Sync → Connect to your server**.
3. Enter **your server's address** (for example `https://<your-server>.vercel.app`), your username and your password. The web app doesn't know your server in advance. A link of the form `.../app/#server=https://<your-server>` fills the address in for you, so you can bookmark it. (The part after `#` stays in your browser; it isn't sent to the site. `?server=` works too.)
4. The device shows up in **Settings → Devices** as, for example, "Safari on iPhone" or "Chrome on Linux".

The server must be version 1.3.0 or newer, because that is the first version that lets browsers talk to it. If you run your own, redeploy it first: see [the web app in the self-hosting guide](self-hosting.md#the-web-app).

After you have opened the app once, it starts without internet too (your tasks are kept in the browser, and changes sync when you are online again). When a new version is out, a bar at the top says **New version**; tap **Reload**.

## On an iPhone: add it to the Home Screen

Safari throws away a website's stored data after a week without a visit, and a tab in Safari can be emptied at any time. A web app **on the Home Screen** keeps its data and opens like an app. So:

1. Open the site in Safari. (Chrome, Edge and Firefox on the iPhone are Safari underneath, with the same limits; they show up under their own names, for example "Chrome on iPhone".)
2. Tap the share button, then **Add to Home Screen**.
3. Open Taskwise **from the Home Screen icon**, and sign in there. The Home Screen app has its own storage, separate from the Safari tab, so sign in again there even if you did it in Safari.

In a Safari tab, Taskwise shows these steps first. If the browser keeps nothing at all (a private window, for example), a bar at the top says so.

## What is different from the apps

- **Two designs:** Brutal and Lapis, each light, dark or by the system. Classic and Slate & Indigo are in the apps only.
- **No reminders yet.** Notifications and location reminders don't fire in the browser. Web notifications are planned (milestone M15). Tasks you add in the browser still sync, and your phone reminds you.
- **No background sync.** The web app syncs while it is open (at start, after changes, every minute and when you come back to it), not while the tab is closed.
- **No Siri or shortcuts, and no in-app updates.** The web app is always the newest version when you reload.
- **Shared computers:** sign out (Settings → Sync) when you are done. Your tasks stay in that browser until you do, and clearing the site's data in the browser also removes them from there (they stay on your server).

If the page says it could not start, the browser could not load the database files. Reload; if it keeps happening, try another browser or check that nothing blocks the site's files.

## Host your own copy

The public site is only one copy. You can host yours (free):

1. Fork the repository on GitHub.
2. Create a Vercel project from the command line, so Vercel's own Git builds stay off. In an empty folder, run `npx vercel@<version> link` and pick a project name. It writes `.vercel/project.json` with the **org id** and **project id**.
3. Make a token at vercel.com/account/tokens.
4. In your fork's **Settings → Secrets and variables → Actions**, add the secrets `VERCEL_TOKEN`, `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`, and the variable `WEB_APP_URL` (your site's address).
5. Publish a release in your fork. The workflow `.github/workflows/web.yml` builds the site (`web/build_site.sh`, checked by `web/test_site.sh`) and deploys it. You can also run it by hand from the Actions tab for a release.

Developing the web app: [dev-setup-fedora.md](dev-setup-fedora.md) (section "The web app") and [architecture.md](architecture.md).
