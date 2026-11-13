# Updates inside the app

From version 1.1.0 on, Taskwise updates itself on Windows, Linux and Android. The iPhone gets a notice only.

## What you see

- About 15 seconds after Taskwise starts, and then about once a day while it runs, Taskwise asks GitHub for the newest **published** release. Drafts and pre-releases are ignored.
- If it's newer, a banner says **Taskwise 1.2.0 is available**. **See what's new** shows the release notes and the button for your device. **Later** hides the banner until Taskwise restarts.
- **Settings → About** has **Check for updates** (checks now) and **Check for updates automatically** (on by default, per device).

| Device | What the button does |
|---|---|
| Windows (the portable folder) | **Update and restart**: downloads the zip, checks it, quits Taskwise, copies the new files over the folder (adding and replacing, never deleting) and starts Taskwise again. |
| Linux AppImage | **Update and restart**: downloads the new AppImage next to the old one, checks it, replaces the file (same name and place) and starts it. |
| Linux tar.gz (installed with `install.sh`) | **Update and restart**: downloads the tar.gz, checks it, swaps `~/.local/share/taskwise` for the new version and starts it. |
| Android | **Update now**: downloads the APK, checks it and hands it to Android. The first time, Android asks to **Allow from this source** for Taskwise; then it shows **Do you want to update this app?**. Taskwise closes after updating; open it again. |
| iPhone | iPhone apps can't install apps, so only a notice and **Open download page**. Install the new `.ipa` with iloader, or let SideStore update it (see [install-ios-sidestore.md](install-ios-sidestore.md#updating-taskwise)). |
| Run from the source (`flutter run`), or an unknown install | A notice and **Open download page**. |

Tasks, settings and the sync sign-in are stored apart from the program (in the app's data folder), so an update keeps them.

## Why it's safe

Every release has two extra files, made by the release workflow:
- `SHA256SUMS`: the SHA-256 fingerprint of every file in the release.
- `SHA256SUMS.sig`: an **Ed25519 signature** of `SHA256SUMS`, made with the Taskwise release key.

The app has the public half of that key built in (`app/lib/update/update_key.dart`). Before installing, it:
1. downloads `SHA256SUMS` and the signature, and refuses both unless the signature matches the built-in key;
2. downloads the update file and checks its SHA-256 against the signed list;
3. deletes the file and installs nothing if either check fails ("The download didn't pass the safety check").

So a changed file, or a release someone else made, is never installed, even if the download address were tampered with. Android also checks that the APK is signed with the same key as the installed app.

## The release key (maintainer)

- **Private key:** `~/.config/taskwise/update-signing-key.pem` on the maintainer's machine, and the GitHub secret **`UPDATE_SIGNING_KEY`** (repository → Settings → Secrets and variables → Actions). Never commit it or paste it anywhere else. To set the secret from the file:
  ```bash
  gh secret set UPDATE_SIGNING_KEY --repo Krkr8/taskwise < ~/.config/taskwise/update-signing-key.pem
  ```
- **Public key:** `app/lib/update/update_key.dart`.
- **Signing:** the release workflow runs `tool/sign_release.sh dist`. It writes `SHA256SUMS` and `SHA256SUMS.sig`, then checks the signature against the public key in the app, so a release signed with the wrong key fails the workflow instead of failing on people's devices. It also attaches `sidestore-source.json` (`tool/make_sidestore_source.sh`).
- **Back the key up** (in a password manager, for example). If it is lost, apps already installed can't take updates signed with a new key: put the new public key in `update_key.dart`, release, and install that version by hand once on every device.
- **If it leaks:** make a new key (`openssl genpkey -algorithm ed25519 -out ~/.config/taskwise/update-signing-key.pem`), replace the secret and the public key (`openssl pkey -in <key> -pubout -outform DER | tail -c 32 | base64`), release, and install that version by hand everywhere.

## Testing an update without a real release

- **Unit tests:** `app/test/update/` (checking, signatures, tampered files, the Linux installers on real files, the restart helper, the openssl/Dart signature format).
- **Against a local fake release** (what was done for M12 on the Android emulator):
  1. Build the app with `--dart-define=TASKWISE_UPDATE_URL=http://10.0.2.2:8765/latest` (the emulator's address for the laptop; on the laptop itself use `127.0.0.1`). Debug builds on Android allow plain HTTP for this; release builds don't.
  2. Build a "newer" one with `--build-name=1.2.0 --build-number=<higher>` and put it in a folder `download/`.
  3. `UPDATE_SIGNING_KEY="$(cat ~/.config/taskwise/update-signing-key.pem)" tool/sign_release.sh download`, then write a `latest` file in the GitHub release JSON shape (`tag_name`, `body`, `assets` with `name` and `browser_download_url`).
  4. `python3 -m http.server 8765` in the folder above `download/`, start the old build, and wait 15 seconds for the banner.
- A build can trust a different key with `--dart-define=TASKWISE_UPDATE_KEY=<base64 public key>` (for forks).
