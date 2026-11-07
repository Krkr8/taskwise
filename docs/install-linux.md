# Install Taskwise on Linux

Taskwise installs for your user only. You don't need `sudo`. The build is for 64-bit x86 Linux; it is tested on Fedora with GNOME, and other distributions with GTK 3 should work too.

## Install or update

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

To update, repeat the same steps with the newer file. `install.sh` replaces the old version. Your tasks stay.

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
| The app | `~/.local/share/taskwise/` |
| Menu entry and icon | `~/.local/share/applications/io.github.krkr8.taskwise.desktop`, `~/.local/share/icons/hicolor/256x256/apps/` |
| **Your tasks** (database) | `~/.local/share/io.github.krkr8.taskwise/` |
| Start-on-login entry (if turned on) | `~/.config/autostart/Taskwise.desktop` |

## Uninstall

From the extracted folder:
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
