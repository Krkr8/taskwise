# Install Taskwise on iPhone

Taskwise isn't on the App Store, so it's **sideloaded**: GitHub builds an unsigned app file (`.ipa`), and a sideloading tool signs it with your free Apple ID and installs it. No Mac is needed: **iloader** runs on Linux, Windows and macOS.

There are two ways:

| | Way 1: iloader only (recommended) | Way 2: iloader + SideStore |
|---|---|---|
| What's on the phone | Only Taskwise | SideStore and Taskwise |
| Every 7 days | Connect the phone to the computer by USB and install the `.ipa` again (2 minutes) | SideStore refreshes on the phone, with a VPN app |
| Works right now | **Yes** (the tested way) | Not fully: Apple blocks sign-in inside SideStore since 2026-10-12 (see Troubleshooting) |
| Extra apps | None | LocalDevVPN, and a pairing file |

Start with **Way 1**. Move to Way 2 later only if you want on-phone refreshes and SideStore's sign-in works again.

> Sources: [iloader](https://iloader.app) and [SideStore docs](https://docs.sidestore.io/docs/installation/prerequisites), checked 2026-10-20. If a screen looks different, those pages are the reference.

## What you need (both ways)

- iPhone with a **passcode** set (iOS 15 or newer)
- A computer and a USB cable
- An **Apple ID**. A secondary/burner one is recommended, because it holds a free developer certificate. It doesn't have to be the Apple ID signed in on the phone. Passwords are case-sensitive.

**Free Apple ID limits:**
- Apps **expire after 7 days** unless they're installed again (refreshed). An expired app won't open, but **your tasks are kept**.
- At most **3 sideloaded apps at once** (SideStore counts as one in Way 2).
- At most **10 different apps (App IDs) per 7 days**.

---

# Way 1: iloader only

## 1. Install iloader on the computer

Download it from <https://iloader.app> or its [releases page](https://github.com/nab138/iloader/releases/latest).

- **Fedora:** it also needs `usbmuxd`, which lets the computer talk to the iPhone:
  ```bash
  sudo dnf install -y usbmuxd
  cd ~/Downloads
  curl -fLO https://github.com/nab138/iloader/releases/latest/download/iloader-linux-x86_64.rpm
  sudo dnf install -y ./iloader-linux-x86_64.rpm
  ```
- **Debian or Ubuntu:** `sudo apt install usbmuxd`, then install iloader's `.deb` or AppImage.
- **Windows:** it needs Apple's iPhone driver. If the phone isn't seen, install **Apple Devices** (or iTunes) from the Microsoft Store.

## 2. Download Taskwise

On the computer, open **[Releases](https://github.com/Krkr8/taskwise/releases/latest)** and download `taskwise-<version>-ios-unsigned.ipa`. Or, with the GitHub CLI:
```bash
cd ~/Downloads
gh release download --repo Krkr8/taskwise --pattern '*ios-unsigned.ipa' --clobber
```

## 3. Install it

1. Connect the iPhone to the computer with USB and unlock it. If the phone asks **Trust This Computer?**, tap **Trust** and enter your passcode.
2. Open **iloader** and sign in with your Apple ID.
3. Select your iPhone, choose **Import IPA**, and pick the `.ipa` from step 2. Wait until it finishes.

If iloader doesn't see the phone, unplug and replug it. Still nothing on Linux? In one terminal run `sudo systemctl stop usbmuxd`, then `sudo usbmuxd -v -f`, and try again in iloader.

## 4. Allow it on the phone (first time only)

1. **Settings → General → VPN & Device Management.** Under **Developer App**, tap your Apple ID → **Trust "…"** → **Trust**.
2. **Settings → Privacy & Security** → scroll to the bottom → **Developer Mode** → on. The phone restarts. After the restart, confirm **Turn On** and enter your passcode.
3. Open **Taskwise** from the home screen.

## Every 7 days

Connect the phone by USB, open iloader, and repeat **step 3** with the same `.ipa` (or a newer one). It installs over the existing app and keeps your tasks. Steps 1, 2 and 4 aren't needed again.

Tip: do it on the same day each week, before the 7 days are up. If you forget, nothing is lost: install it again and Taskwise opens with your tasks.

## Updating Taskwise

iPhone apps can't update themselves, so from version 1.1.0 on Taskwise only tells you: a banner says a new version is out, with what's new and a link to the release. Download the newer `.ipa` (step 2) and install it (step 3). It replaces the old version and keeps your tasks, and it also counts as this week's refresh.

---

# Way 2: iloader + SideStore

SideStore is an app on the phone that re-signs and refreshes your apps without the computer. It's set up once from the computer with iloader. You also need the phone and computer on the **same Wi-Fi** for the setup (mobile data doesn't work for SideStore).

> **Status (2026-10-30):** Apple currently blocks sign-in inside SideStore (error -80045, see Troubleshooting). Until that's fixed, SideStore can't install or refresh Taskwise, so use **Way 1**.

## Part 1: Computer

1. Install **iloader** (see Way 1, step 1).

## Part 2: Phone, before connecting

2. Install **LocalDevVPN** from the App Store: <https://apps.apple.com/us/app/localdevvpn/id6755608044>. Open it, tap **Connect**, and allow the VPN configuration. SideStore needs this VPN **every time** it installs or refreshes an app.

## Part 3: Install SideStore with iloader

3. Connect the iPhone to the computer with USB. If the phone asks **Trust This Computer?**, tap **Trust** and enter your passcode.
4. Open **iloader**.
5. Sign in with your Apple ID.
6. Select your iPhone, then choose **Install SideStore (Stable)**. Wait until it finishes.
7. Place the **pairing file** (it lets SideStore talk to the phone without the computer):
   1. Click **Delete Stored Pairing**.
   2. Click your device and tap **Trust** on the phone.
   3. Click **Manage Pairing File**, then **Place** next to SideStore. Wait for "Pairing file placed successfully!" in green.

## Part 4: Phone, enable and trust

8. **Settings → General → VPN & Device Management.** Under **Developer App**, tap your Apple ID → **Trust "…"** → **Trust** (or **Allow & Restart**), and enter your passcode if asked.
9. **Settings → Privacy & Security** → scroll to the bottom → **Developer Mode** → on. The phone restarts. After the restart, confirm **Turn On**.
10. Open **LocalDevVPN** → **Connect**.
11. Open **SideStore** and sign in with the **same Apple ID** you used in iloader.
12. In SideStore go to **My Apps** and tap the **7 DAYS** button next to SideStore to refresh it. If it asks about the signing certificate, tap **Yes** / **Refresh Now**. Do this **before installing anything else**.

## Part 5: Install Taskwise with SideStore

13. Download `taskwise-<version>-ios-unsigned.ipa` in **Safari on the phone** from **[Releases](https://github.com/Krkr8/taskwise/releases/latest)**. It goes to **Files → Downloads**.
14. Connect **LocalDevVPN**, then in **SideStore → My Apps** tap **+** and pick the file.
15. Open **Taskwise** from the home screen.

*This path hasn't been tested with Taskwise yet.* If it fails, install Taskwise with iloader instead (Way 1, step 3); SideStore can still refresh it afterwards.

## Every week (SideStore)

SideStore refreshes apps in the background. To do it yourself, connect **LocalDevVPN**, open **SideStore → My Apps**, and tap **Refresh All**.

## Updating Taskwise (SideStore)

Add Taskwise's source once, and SideStore shows and installs updates on the phone. In SideStore, open **Sources → +** and enter:
```
https://github.com/Krkr8/taskwise/releases/latest/download/sidestore-source.json
```

## Only one VPN at a time

iOS runs **one VPN at a time**, and SideStore needs LocalDevVPN to install and refresh apps. If you use another VPN, switch LocalDevVPN on while you refresh or install (which turns the other VPN off), then switch the other VPN back on afterwards. Taskwise doesn't need a VPN: its sync server is reached over normal HTTPS. Way 1 doesn't need LocalDevVPN at all.

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

  If it still fails, use **Way 1** and check the SideStore issue for newer fixes.
- **iloader problems** are supported on the *idevice* Discord, not SideStore's.

What a free Apple ID can and can't do is in [ios-free-apple-id.md](ios-free-apple-id.md).
