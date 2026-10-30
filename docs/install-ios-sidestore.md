# Install Taskwise on iPhone with SideStore (from Fedora)

You don't have a Mac and Taskwise isn't on the App Store, so it's **sideloaded**: GitHub builds an unsigned app file (`.ipa`), and **SideStore** on the phone signs it with your free Apple ID and installs it.

You need the Fedora laptop for the initial setup over USB. While SideStore's sign-in is broken (see Part 5), you also need it once a week to refresh the app.

> Sources: [SideStore docs](https://docs.sidestore.io/docs/installation/prerequisites) and [iloader](https://iloader.app), checked 2026-10-20. If a screen looks different, those pages are the reference.

## What you need

- iPhone with a **passcode** set (iOS 15 or newer)
- A USB cable, and the phone and laptop on the **same Wi-Fi** (mobile data doesn't work for SideStore)
- An **Apple ID**. A secondary/burner one is recommended, because it holds a free developer certificate. It doesn't have to be the Apple ID signed in on the phone. Passwords are case-sensitive.

## Free Apple ID limits (read this once)

- At most **3 sideloaded apps at once, SideStore included**: SideStore + Taskwise leaves one spare slot.
- At most **10 different apps (App IDs) per 7 days**.
- Apps **expire after 7 days** unless refreshed. SideStore refreshes them (see "Every week" below).

## Part 1: Laptop (Fedora)

1. Install `usbmuxd` (it lets Linux talk to the iPhone) and **iloader** (SideStore's installer):
   ```bash
   sudo dnf install -y usbmuxd
   cd ~/Downloads
   curl -fLO https://github.com/nab138/iloader/releases/latest/download/iloader-linux-x86_64.rpm
   sudo dnf install -y ./iloader-linux-x86_64.rpm
   ```

## Part 2: Phone, before connecting

2. Install **LocalDevVPN** from the App Store: <https://apps.apple.com/us/app/localdevvpn/id6755608044>. Open it, tap **Connect**, and allow the VPN configuration. SideStore needs this VPN **every time** it installs or refreshes an app.

## Part 3: Install SideStore with iloader

3. Connect the iPhone to the laptop with USB. If the phone asks **Trust This Computer?**, tap **Trust** and enter your passcode.
4. Open **iloader** (Activities → search "iloader").
5. Sign in with your Apple ID.
6. Select your iPhone, then choose **Install SideStore (Stable)**. Wait until it finishes.
7. Place the **pairing file** (it lets SideStore talk to the phone without the laptop):
   1. Click **Delete Stored Pairing**.
   2. Click your device and tap **Trust** on the phone.
   3. Click **Manage Pairing File**, then **Place** next to SideStore. Wait for "Pairing file placed successfully!" in green.

If iloader doesn't see the phone, unplug and replug it. Still nothing? In one terminal run `sudo systemctl stop usbmuxd`, then `sudo usbmuxd -v -f`, and try again in iloader.

## Part 4: Phone, enable and trust

8. **Settings → General → VPN & Device Management.** Under **Developer App**, tap your Apple ID → **Trust "…"** → **Trust** (or **Allow & Restart**), and enter your passcode if asked.
9. **Settings → Privacy & Security** → scroll to the bottom → **Developer Mode** → on. The phone restarts. After the restart, confirm **Turn On**.
10. Open **LocalDevVPN** → **Connect**.
11. Open **SideStore** and sign in with the **same Apple ID** you used in iloader.
12. In SideStore go to **My Apps** and tap the **7 DAYS** button next to SideStore to refresh it. If it asks about the signing certificate, tap **Yes** / **Refresh Now**. Do this **before installing anything else**.

## Part 5: Install Taskwise

> **Status (2026-10-30):** Apple currently blocks sign-in inside SideStore (error -80045, see Troubleshooting), but iloader on the laptop still works. So for now Taskwise is installed **from the laptop with iloader** (this is how it was first installed and confirmed). SideStore stays on the phone, and can take over once its sign-in works again.

13. On the laptop, download the iPhone build (it's `taskwise-<version>-ios-unsigned.ipa` on the release). If the release is still a **Draft**, it's only visible while you're signed in to GitHub as the repository owner. With the GitHub CLI:
    ```bash
    mkdir -p ~/Downloads/taskwise-ios && cd ~/Downloads/taskwise-ios
    gh release download v0.1.0 --repo Krkr8/taskwise --pattern '*ios-unsigned.ipa' --clobber
    ```
    (Replace `v0.1.0` with the newest version.)
14. Connect the iPhone by USB and unlock it. Open **iloader** (signed in with your Apple ID), select the phone, choose **Import IPA**, and pick the downloaded `.ipa`. Wait until it finishes.
15. Open **Taskwise** from the home screen.

**Installing from SideStore instead (once its sign-in works):** download the `.ipa` in Safari on the phone (it goes to **Files → Downloads**), connect **LocalDevVPN**, then in **SideStore → My Apps** tap **+** and pick the file. *This path hasn't been tested with Taskwise yet.*

## Every week

- Apps expire **7 days** after they were last signed (this is Apple's limit for free Apple IDs). An expired app won't open, but **your tasks are kept**.
- **With iloader (current way):** connect the phone by USB and repeat step 14 with the same `.ipa`. It installs over the existing app.
- **With SideStore (when its sign-in works):** SideStore refreshes apps in the background. To do it yourself, connect **LocalDevVPN**, open **SideStore → My Apps**, and tap **Refresh All**.

## Updating Taskwise

Download the newer `.ipa` (step 13) and install it the same way (step 14). It replaces the old version and keeps your tasks.

## Only one VPN at a time

iOS runs **one VPN at a time**, and SideStore needs LocalDevVPN to install and refresh apps. If you use another VPN, switch LocalDevVPN on while you refresh or install (which turns the other VPN off), then switch the other VPN back on afterwards. Taskwise doesn't need a VPN: its sync server is reached over normal HTTPS.

## Troubleshooting (from SideStore's docs)

- **Connection errors in SideStore:** make sure LocalDevVPN and Wi-Fi are both connected, turn off DNS/ad blockers, then restart LocalDevVPN and SideStore.
- **Errors after an iOS update or reset:** the pairing file can expire. Redo step 7 with iloader.
- **Sign-in errors:** usually a temporary "Anisette" server outage. Wait, or pick another server under SideStore **Settings → Anisette URL**.
- **Sign-in fails with -80045 or -80046:** since 2026-10-12, Apple's sign-in server rejects the device identity ("anisette") that free sideloaders send, and it has changed more than once since then. This community workaround ([SideStore issue #1688](https://github.com/SideStore/SideStore/issues/1688)) uses a server run by a SideStore developer:
  0. If SideStore says a newer version exists, reinstall it with the latest iloader first (step 6).
  1. SideStore **Settings → User Customizations** → turn **On-Device Anisette** off (allow the restart).
  2. **Settings → Anisette servers** → pick **SideStore (New)**, then at the bottom turn **Enable auto rotation** off.
  3. **User Customizations → Anisette client configuration** → **Remote server sync** → **Fetch** → **Save as overrides**.
  4. **User Customizations → Reset adi.pb**.
  5. Connect LocalDevVPN and sign in again (it's slow).

  If it still fails, install the `.ipa` from the laptop with iloader (see the fallback in Part 5), and check the SideStore issue for newer fixes.
- **iloader problems** are supported on the *idevice* Discord, not SideStore's.

What a free Apple ID can and can't do is in [ios-free-apple-id.md](ios-free-apple-id.md).
