# Install Taskwise on Android

Taskwise isn't on Google Play. You install the APK file from GitHub yourself ("sideloading"). It needs Android 8.0 or newer. Location reminders also need Google Play services, which almost every phone has (not Huawei phones without Google).

## Install

1. **Download.** On the phone, open **[Releases](https://github.com/Krkr8/taskwise/releases/latest)** in the browser and tap `taskwise-<version>-android.apk`.
2. **Open the file.** When the download finishes, tap **Open** (or find it in the **Files** app → **Downloads**).
3. **Allow installing.** The first time, Android says your browser isn't allowed to install apps. Tap **Settings**, turn on **Allow from this source**, and go back.
4. Tap **Install**. If **Google Play Protect** warns that it doesn't know the app, tap **More details → Install anyway**. It warns because Taskwise isn't from the Play Store.
5. Open Taskwise from the app list.

**Updating:** download the newer APK and install it the same way. Android replaces the old version and keeps your tasks and sign-in. Every release is signed with the same key, so updates install over each other. A build you make yourself is signed with a different key, so uninstall the release first.

## Permissions

Taskwise asks only when it needs something:

- **Notifications:** asked when you add the first reminder. Choose **Allow**.
- **Location** (only for location reminders): Taskwise explains why first. Then:
  1. Choose **While using the app** and keep **Precise** on.
  2. Android opens Taskwise's location settings: choose **Allow all the time**, then go back.

  Without "all the time", location reminders can't remind you while Taskwise is closed. Settings → Location reminders → **Location access** shows what Android allows, with a button to its settings page.

Your location stays on your phone. It's never sent to the sync server.

## Make reminders reliable

Android may stop apps in the background to save battery. To make sure reminders come on time:

- **Battery:** Settings → **Apps** → **Taskwise** → **Battery** (or **App battery usage**) → **Unrestricted**.
- **Location reminders** need **Location Accuracy** on: Settings → **Location** → **Location services** → **Location Accuracy** → **Improve Location Accuracy**. Without it Android can't watch places (Location debug shows "turn on Location Accuracy").
- **Samsung, Xiaomi, OnePlus, Huawei and others** have their own extra battery savers that can stop reminders. [dontkillmyapp.com](https://dontkillmyapp.com) explains the setting for each brand.

## How reminders work on Android

- **Time reminders** are scheduled with Android itself, so they come on time even when Taskwise is closed or the phone restarts. A notification has **Done** and **Snooze** buttons. Android shows at most three buttons, so the third snooze length (if you picked three in Settings → Notifications) only shows on the iPhone and desktop.
- **Location reminders** work like on the iPhone: Android watches an area of about 150 m around the place (100 m for "leave"). When you enter or leave it, Taskwise checks your position precisely for up to 5 minutes. During that check a quiet notification, "Checking your location for a reminder…", is shown, because Android requires one. "Leave" usually reminds you 150-400 m from the place, after Android notices you left the area.
- **Sync** runs while Taskwise is open, and about every 30 minutes in the background (Android decides exactly when; less often in battery saver).

## Uninstall

Long-press the Taskwise icon → **Uninstall** (or Settings → Apps → Taskwise → **Uninstall**). This deletes the tasks on this phone. Tasks that were synced stay on your server and your other devices.

## Troubleshooting

- **"App not installed"** when updating: the installed Taskwise was signed with a different key (e.g. one you built yourself). Uninstall it first. Your synced tasks come back when you sign in again.
- **No reminders:** check that notifications are on for Taskwise (Settings → Apps → Taskwise → Notifications), battery use is **Unrestricted**, and **Do not disturb** is off.
- **Location reminders don't fire:** open Taskwise → Settings → Location reminders → **Location debug**. It shows the location access, the watched areas and the last 50 events. Send a screenshot of it when reporting a problem.
- **Logs:** Settings → About → **View logs**.
