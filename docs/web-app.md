# Taskwise in the browser

Taskwise also runs in a web browser: the same app, on any computer or phone, with nothing to install. It is the same code as the Windows, Linux, iPhone and Android apps.

The public site is **[taskwise-web.vercel.app](https://taskwise-web.vercel.app)** <!-- WEB_APP_URL --> (also in the repository's website field on GitHub). The home page there has the download links for every platform. The app itself is at `/app/` on the same address.

## Use it

1. Open the site and choose **Open Taskwise in the browser**.
2. Taskwise works on its own, in the browser's storage. To share your tasks with your other devices, sign in to your own sync server: **Settings → Sync → Connect to your server**.
3. Enter **your server's address** (for example `https://<your-server>.vercel.app`), your username and your password. The web app doesn't know your server in advance. A link of the form `.../app/#server=https://<your-server>` fills the address in for you, so you can bookmark it. (The part after `#` stays in your browser; it isn't sent to the site. `?server=` works too.)
4. The device shows up in **Settings → Devices** as, for example, "Safari on iPhone" or "Chrome on Linux".

The server must be version 1.3.0 or newer, because that is the first version that lets browsers talk to it. If you run your own, redeploy it first: see [the web app in the self-hosting guide](self-hosting.md#the-web-app).

After you have opened the app once, it starts without internet too (your tasks are kept in the browser, and changes sync when you are online again). When a new version is out, a bar says a new version of Taskwise is ready; tap **Reload**.

## On an iPhone: add it to the Home Screen

Safari throws away a website's stored data after a week without a visit, and a tab in Safari can be emptied at any time. A web app **on the Home Screen** keeps its data and opens like an app. So:

1. Open the site in Safari. (Chrome, Edge and Firefox on the iPhone are Safari underneath, with the same limits; they show up under their own names, for example "Chrome on iPhone".)
2. Tap the share button, then **Add to Home Screen**.
3. Open Taskwise **from the Home Screen icon**, and sign in there. The Home Screen app has its own storage, separate from the Safari tab, so sign in again there even if you did it in Safari.

In a Safari tab, Taskwise shows these steps first. If the browser keeps nothing at all (a private window, for example), a bar at the top says so.

## Reminders in the browser

The web app can show your reminders as notifications, sent by your sync server at the reminder's time (Web Push), even while the app is closed.

1. Your server must be set up for it: see [Web reminders in the self-hosting guide](self-hosting.md#web-reminders). Until it is, **Settings → Notifications** says "This server isn't set up for reminders yet."
2. In the web app, open **Settings → Notifications** and tap **Turn on notifications in this browser**. Allow notifications when the browser asks.
3. It then says "Notifications are on in this browser." and until when reminders are planned (the next 60 days, up to 500 reminders). **Turn off** stops them for this browser. If the server can't plan them (for example, a Vercel server without Queues), it says "Reminders couldn't be planned on the server. They'll be retried." instead.

Tapping a notification opens Taskwise on that task. Reminders reach this browser when the task notifies on it: in a task's **Notify on**, a browser without notifications shows "(notifications off)".

**iPhone and iPad:** notifications only work in the **Home Screen app** (iOS 16.4 or newer), not in a Safari tab. Add Taskwise to the Home Screen first (see above), open it from there and turn notifications on in its Settings. A Safari tab says so and shows the steps.

If the browser says notifications are blocked, allow them for the site in the browser's settings (on an iPhone: **Settings → Notifications → Taskwise**), then open Settings in Taskwise again.

Limits:
- **No buttons** on the notification (iPhones show none): tap it and tick the task off in the app. There is no snooze from a web notification.
- **Taskwise 1.4.0 on your other devices:** they plan the browser's reminders, so they need 1.4.0 or newer. Older ones sync as before but plan nothing for the browser.
- **One time zone:** your other devices plan the browser's reminders only when their time zone shows the same clock as the browser's (for example Riyadh and Baghdad) over the next 60 days. Otherwise the browser plans its own whenever it is open. All-day tasks remind at the browser's own **all-day reminder time**.
- **Location reminders** don't fire in the browser.
- Each browser (and each iPhone Home Screen app) turns notifications on by itself. If the push service drops a browser's subscription, the browser subscribes again by itself the next time Taskwise opens there. Signing out, or clearing the site's data, turns them off: turn them on again after signing in.
- **Not built (yet):** a warning when the browser's planned reminders run out within 7 days (when no other device has planned them for a while), and a fallback when the server's queue isn't available.

## What is different from the apps

- **Two designs:** Brutal and Lapis, each light, dark or by the system. Classic and Slate & Indigo are in the apps only.
- **Reminders by Web Push only:** time reminders arrive as notifications once you turn them on (see above); location reminders don't fire in the browser.
- **No background sync.** The web app syncs while it is open (at start, after changes, every minute and when you come back to it), not while the tab is closed.
- **No Siri or shortcuts, and no in-app updates.** The web app is always the newest version when you reload.
- **Shared computers:** sign out (Settings → Sync) when you are done, with **Also remove my tasks from this browser** ticked (it is unless you untick it). The browser then forgets your tasks, settings and the app's log, and the page starts again empty. Your tasks stay on your server and your other devices. If you untick it, your tasks stay in that browser until you clear the site's data.

If the page says it could not start, the browser could not load the database files. Reload; if it keeps happening, try another browser or check that nothing blocks the site's files.

## Host your own copy

The public site is only one copy. You can host yours (free):

1. Fork the repository on GitHub. GitHub turns Actions off in a fork: open your fork's **Actions** tab and enable the workflows first.
2. Create a Vercel project from the command line, so Vercel's own Git builds stay off. In an empty folder, run `npx vercel@65.15.0 link`. Answer that you don't want to link an existing project, so it creates a new one, and pick a project name; the framework is **Other**, with no build command (the workflow uploads a site that is already built). It writes `.vercel/project.json` with the **org id** and **project id**.
3. Make a token at vercel.com/account/tokens.
4. In your fork's **Settings → Secrets and variables → Actions**, add the secrets `VERCEL_TOKEN`, `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`, and the variable `WEB_APP_URL` (your site's address).
5. Publish a release in your fork. The workflow `.github/workflows/web.yml` builds the site (`web/build_site.sh`, checked by `web/test_site.sh`) and deploys it. You can also run it by hand from the Actions tab for a release; tick **preview** to deploy to a preview address first (production stays as it is).

Developing the web app: [dev-setup-fedora.md](dev-setup-fedora.md) (section "The web app") and [architecture.md](architecture.md).
