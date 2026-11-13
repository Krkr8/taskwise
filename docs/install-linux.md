# Install Taskwise on Linux

Taskwise comes in two forms for 64-bit x86 Linux. Neither needs `sudo`.

- **AppImage:** one file that runs on most distributions (Debian 12 or newer, Ubuntu 22.04 or newer, Arch, Fedora, Linux Mint, Manjaro…). Nothing to install.
- **tar.gz with `install.sh`:** installs Taskwise for your user, with a menu entry.

Both are the same app and keep your tasks in the same place, so you can switch between them. Taskwise is tested on Fedora with GNOME; every AppImage release is also started on Debian 12, Ubuntu 22.04 and 24.04 and Arch (`tool/appimage_smoke_test.sh`).

## AppImage (any distribution)

1. Open **[Releases](https://github.com/Krkr8/taskwise/releases/latest)** and download `taskwise-<version>-linux-x86_64.AppImage`. Or, with the GitHub CLI:
   ```bash
   mkdir -p ~/Applications && cd ~/Applications
   gh release download --repo Krkr8/taskwise --pattern '*.AppImage'
   ```
2. Make it executable and start it:
   ```bash
   chmod +x ~/Applications/taskwise-*-linux-x86_64.AppImage
   ~/Applications/taskwise-*-linux-x86_64.AppImage
   ```
   In a file manager you can also right-click it → **Properties** → allow it to run as a program, then double-click it.
3. To get it in the app menu, use [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever) or AppImageLauncher, or install the tar.gz below instead.

**Updating:** from version 1.1.0 on, Taskwise updates itself: when a banner says a new version is out, tap **See what's new → Update and restart** (or **Settings → About → Check for updates**). It replaces the AppImage file where it is, keeping its name and place, so menu entries and **Start when I log in** keep working. ([How it works](updates.md).)

To update by hand, download the new AppImage and delete the old one. If **Start when I log in** is on, open the new file once so the login entry points at it.

**If it doesn't start:**
- *"AppImages require FUSE to run"* (some Ubuntu and Debian installs): install FUSE with `sudo apt install libfuse2t64` (Ubuntu 24.04+) or `sudo apt install libfuse2` (Debian, older Ubuntu). Or run it without FUSE: `./taskwise-*.AppImage --appimage-extract-and-run`.
- *"Couldn't open libEGL.so.1"* or *"libGLESv2.so.2"* (only on very minimal installs): install the graphics libraries with `sudo apt install libegl1 libgles2` (Debian, Ubuntu) or `sudo pacman -S mesa` (Arch).
- **Signing in to a sync server** keeps the device token in your desktop's keyring (GNOME Keyring or KWallet). On a desktop without one, install `gnome-keyring`.
- Run it from a terminal to see error messages.

## Install or update (tar.gz)

1. Open **[Releases](https://github.com/Krkr8/taskwise/releases/latest)** and download `taskwise-<version>-linux-x64.tar.gz` (into `~/Downloads`, say). Or, with the GitHub CLI:
   ```bash
   cd ~/Downloads
   gh release download --repo Krkr8/taskwise --pattern '*linux-x64.tar.gz'
   ```
2. Extract it and run the installer:
   ```bash
   tar -xzf taskwise-*-linux-x64.tar.gz
   cd taskwise-*-linux-x64
   ./install.sh
   ```
3. Press the Super key, type **Taskwise** and open it. You can right-click the icon in the dash and choose **Pin to Dash**.

**Updating:** from version 1.1.0 on, Taskwise updates itself (a banner, then **Update and restart**; see [updates.md](updates.md)). To update by hand, repeat the same steps with the newer file. `install.sh` replaces the old version. Your tasks stay.

## Reminders and running in the background

Linux can't schedule notifications ahead, so **reminders only appear while Taskwise is running**. Closing the window doesn't quit it: Taskwise keeps running in the background and shows reminders on time. To quit for real, use **Quit Taskwise** in the tray menu, or turn off **Settings → Background → Keep running when the window is closed** and close the window.

- **Tray icon on GNOME:** GNOME only shows tray icons with the AppIndicator extension. To get it:
  ```bash
  sudo dnf install -y gnome-shell-extension-appindicator     # Fedora
  sudo apt install gnome-shell-extension-appindicator        # Debian, Ubuntu
  ```
  Log out and back in, then turn it on in the **Extensions** app. The teal check icon appears at the top right; click it for **Show Taskwise** / **Quit Taskwise**.
- **Without the extension** Taskwise still runs in the background. Open it again from Activities and the existing window comes back (only one copy ever runs).
- **Start on login:** turn on **Settings → Background → Start when I log in**. Taskwise then starts hidden in the background when you log in, so reminders work all day. (It adds `~/.config/autostart/Taskwise.desktop`.)
- **Missed reminders:** if Taskwise wasn't running when a reminder was due, it shows reminders from the last 24 hours when it starts.

## Where things are

| What | Where |
|---|---|
| The app | `~/.local/share/taskwise/` (tar.gz), or wherever you keep the AppImage |
| Menu entry and icon | `~/.local/share/applications/io.github.krkr8.taskwise.desktop`, `~/.local/share/icons/hicolor/256x256/apps/` |
| **Your tasks** (database) | `~/.local/share/io.github.krkr8.taskwise/` |
| Start-on-login entry (if turned on) | `~/.config/autostart/Taskwise.desktop` |

## Uninstall

AppImage: delete the file. tar.gz: from the extracted folder, run:
```bash
./install.sh --uninstall
```
This removes the app but keeps your tasks. To erase them as well:
```bash
rm -rf ~/.local/share/io.github.krkr8.taskwise
```

## Troubleshooting

- **"Permission denied" when running `./install.sh`:** run `chmod +x install.sh` first.
- **Taskwise doesn't show up in Activities:** log out and back in once.
- **No reminders appear:** check that Taskwise is running (tray icon, or open it), and that GNOME notifications aren't paused (**Do Not Disturb** in the top-right menu).
- **Run it from a terminal to see error messages:** `~/.local/share/taskwise/taskwise`. GTK warnings such as `Atk-CRITICAL` are harmless.
