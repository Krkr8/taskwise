# Install Taskwise on Windows 11

Taskwise comes as a portable folder. There's no installer and you don't need admin rights.

## Install or update

1. **Download.** On the PC, sign in to github.com (the repository is private) and open **Krkr8/taskwise → Releases**. Download `taskwise-<version>-windows-x64.zip`.
2. **Unblock the zip** (this avoids a security prompt for every file). Right-click the zip → **Properties** → tick **Unblock** at the bottom → **OK**.
3. **Extract.** Right-click the zip → **Extract All…** → enter this folder and click **Extract**:
   ```
   %LOCALAPPDATA%\Programs
   ```
   You now have `%LOCALAPPDATA%\Programs\Taskwise\taskwise.exe`.
4. **First start.** Open that folder and double-click `taskwise.exe`. If **"Windows protected your PC"** (SmartScreen) appears, click **More info → Run anyway**. Windows shows this because the app isn't code-signed. It's only asked once.
5. **Start menu shortcut** (optional). Right-click `taskwise.exe` → **Show more options** → **Pin to Start**, or **Send to → Desktop (create shortcut)**.

To update, close Taskwise, then extract the new zip into the same `%LOCALAPPDATA%\Programs` folder and choose **Replace the files in the destination**. Your tasks stay.

## Where things are

| What | Where |
|---|---|
| The app | `%LOCALAPPDATA%\Programs\Taskwise\` |
| **Your tasks** (database) | `%APPDATA%\io.github.krkr8\Taskwise\` (built from the app's company and product names; paste the path into the File Explorer address bar to open it) |

## Uninstall

Delete `%LOCALAPPDATA%\Programs\Taskwise` and any shortcuts. To erase your tasks too, delete the data folder above.

## Troubleshooting

- **"VCRUNTIME140.dll was not found":** shouldn't happen, because the zip includes the Visual C++ runtime files. If it does, install the "Microsoft Visual C++ Redistributable (x64)" from Microsoft's website.
- **Nothing happens on double-click:** make sure you extracted the zip and aren't running the exe from inside it.
