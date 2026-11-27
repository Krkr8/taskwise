# Development setup on Fedora

These steps set up a Fedora 44 (GNOME) machine to build and run the Taskwise Linux app, and to work on the sync server. Windows and iOS builds run on GitHub Actions, so you don't need anything else locally.

## 1. System packages

Flutter's Linux desktop toolchain needs clang, CMake, Ninja, pkg-config, GTK 3 headers and the C++ standard library headers. The tray icon (`tray_manager`) also needs the X11 and Xi headers, and the sign-in token store (`flutter_secure_storage`, which keeps the token in the GNOME keyring) needs libsecret:

```bash
sudo dnf install -y git clang cmake ninja-build pkgconf-pkg-config gtk3-devel libstdc++-devel libX11-devel libXi-devel libsecret-devel xz
```

To build the Linux AppImage locally (`tool/package_appimage.sh`, after `flutter build linux --release`), also install `patchelf`; `tool/appimage_smoke_test.sh` needs `podman`:

```bash
sudo dnf install -y patchelf podman
```

The GitHub CLI is optional but handy for checking CI runs:

```bash
sudo dnf install -y gh
gh auth login
```

## 2. Flutter SDK

The project uses Flutter **3.47.7** (stable). The same version is pinned in `.github/workflows/ci.yml`.

```bash
mkdir -p ~/development
cd ~/development
curl -fLO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz
tar -xf flutter_linux_3.47.7-stable.tar.xz
rm flutter_linux_3.47.7-stable.tar.xz
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Turn off platforms Taskwise doesn't target, so `flutter doctor` stays quiet about them:

```bash
flutter config --no-enable-android
flutter doctor -v
```

`flutter doctor` should show a green check for **Linux toolchain**. It may warn about Android Studio, Chrome or Xcode, and you can ignore those.

## 3. Node.js (for the sync server)

The sync server in `server/` is TypeScript and needs **Node.js 24** (the version Vercel runs it on). Skip this if `node --version` already prints `v24.…`. Otherwise install the official build into your home folder:

```bash
cd /tmp
curl -fsSLO https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt
FILE=$(grep -o 'node-v24[^ ]*-linux-x64.tar.xz' SHASUMS256.txt)
curl -fsSLO "https://nodejs.org/dist/latest-v24.x/$FILE"
sha256sum -c --ignore-missing SHASUMS256.txt
mkdir -p ~/.local/node && tar -xf "$FILE" -C ~/.local/node --strip-components=1
echo 'export PATH="$HOME/.local/node/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
node --version
```

## 4. Get the code and run it

```bash
gh repo clone Krkr8/taskwise
cd taskwise
flutter pub get
cd app
flutter run -d linux
```

For the sync server, see "Running the server locally" in [server-setup-vercel.md](server-setup-vercel.md).

## 5. The web app

The same app runs in a browser (Flutter web; the web-only files are in `app/web/`). Without a browser, start Flutter's web server and open the address it prints in any browser on the machine:

```bash
cd app
flutter run -d web-server --web-port 8080
```

`app/web_dev_config.yaml` makes this server send the same cross-origin isolation headers as the real site (`web/site/vercel.json`), so the browser offers the same storage (OPFS) as there. The app log (Settings → About → View logs) says which storage the browser picked: `Browser storage: opfsLocks` in Chrome.

### Chrome for Testing (no sudo)

For `flutter run -d chrome` and the browser test, install Chrome for Testing and its matching chromedriver into your home folder (versions pinned; any newer pair of the same version works too):

```bash
mkdir -p ~/.local/share/chrome-for-testing
cd ~/.local/share/chrome-for-testing
npx -y @puppeteer/browsers@3.2.7 install chrome@158.0.8127.88 --path ~/.local/share/chrome-for-testing
npx -y @puppeteer/browsers@3.2.7 install chromedriver@158.0.8127.88 --path ~/.local/share/chrome-for-testing
```

Chrome then is `~/.local/share/chrome-for-testing/chrome/linux-158.0.8127.88/chrome-linux64/chrome`. To use it with `flutter run -d chrome`:

```bash
export CHROME_EXECUTABLE=~/.local/share/chrome-for-testing/chrome/linux-158.0.8127.88/chrome-linux64/chrome
```

If Chrome doesn't start because of missing libraries, `ldd` on that file lists them (Fedora with GNOME already has them).

### The browser test

`app/integration_test/web_smoke_test.dart` runs the app in Chrome against a local sync server: it signs in, adds a task, finds it on the server, reloads the page and opens a second tab. CI runs it in the `web` job. Locally, with three terminals (or `&`):

```bash
# 1. A throwaway sync server (in memory)
cd server && DATABASE_URL=:memory: SETUP_SECRET=live-test-secret PORT=8787 npx tsx src/node.ts

# 2. chromedriver
~/.local/share/chrome-for-testing/chromedriver/linux-158.0.8127.88/chromedriver-linux64/chromedriver --port=4444

# 3. The test (takes about 2 minutes)
cd app
flutter drive -d web-server --browser-name=chrome \
  --chrome-binary=$HOME/.local/share/chrome-for-testing/chrome/linux-158.0.8127.88/chrome-linux64/chrome \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/web_smoke_test.dart \
  --dart-define=SERVER=http://localhost:8787
```

It prints `All tests passed.`; the steps it did and the storage the browser picked are in `app/build/integration_response_data.json`. Add `--no-headless` to watch it. Stop the server and chromedriver (Ctrl+C) afterwards.

### The site

`web/build_site.sh <version> <out_dir>` builds the whole site (home page and the app under `/app/`) into a folder outside the repository, and `web/test_site.sh <out_dir>` checks it:

```bash
web/build_site.sh 1.3.0 /tmp/taskwise-site && web/test_site.sh /tmp/taskwise-site
```

The output folder must be new, empty, or an earlier output of the script (it has a `.taskwise-site` file): the script deletes it first, and refuses any other folder.

Then check the built site in Chrome for Testing (about a minute; it prints `All browser checks passed.`): an update that was never reloaded must still start offline, a server that never answers too, and a first visit in English and in Arabic must fetch nothing from other hosts (it lists the hosts). An optional third argument saves screenshots there.

```bash
node web/test_site_browser.mjs /tmp/taskwise-site \
  ~/.local/share/chrome-for-testing/chrome/linux-158.0.8127.88/chrome-linux64/chrome
```

GitHub Actions deploys it to Vercel when a release is published (`.github/workflows/web.yml`).

## Troubleshooting: `flutter test` fails with "Building native assets failed"

The tray library compiles its native code when tests start. If your `PATH` contains Fedora's ccache wrappers (`/usr/lib64/ccache`, added by the `ccache` package), that build picks `ccache` itself as the compiler and fails. Run the tests without that folder on `PATH`:

```bash
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v ccache | paste -sd:) flutter test
```

`flutter build linux` and `flutter run -d linux` aren't affected (they use CMake).
