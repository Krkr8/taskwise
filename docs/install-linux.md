# Install Taskwise on Linux (Fedora)

Taskwise installs for your user only. You don't need `sudo`.

## Install or update

1. Download the latest Linux build. Because the repository is private, use the GitHub CLI (you're already logged in) or the website while signed in:
   ```bash
   cd ~/Downloads
   gh release download --repo Krkr8/taskwise --pattern '*linux-x64.tar.gz'
   ```
   On the website, open **Releases** and download `taskwise-<version>-linux-x64.tar.gz`.
2. Extract it and run the installer:
   ```bash
   tar -xzf taskwise-*-linux-x64.tar.gz
   cd taskwise-*-linux-x64
   ./install.sh
   ```
3. Press the Super key, type **Taskwise** and open it. You can right-click the icon in the dash and choose **Pin to Dash**.

To update, repeat the same steps with the newer file. `install.sh` replaces the old version. Your tasks stay.

## Where things are

| What | Where |
|---|---|
| The app | `~/.local/share/taskwise/` |
| Menu entry and icon | `~/.local/share/applications/io.github.krkr8.taskwise.desktop`, `~/.local/share/icons/hicolor/256x256/apps/` |
| **Your tasks** (database) | `~/.local/share/io.github.krkr8.taskwise/` |

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
- **Run it from a terminal to see error messages:** `~/.local/share/taskwise/taskwise`. GTK warnings such as `Atk-CRITICAL` are harmless.
