# Development setup on Fedora

These steps set up a Fedora 44 (GNOME) machine to build and run the Taskwise Linux app. Windows and iOS builds run on GitHub Actions, so you don't need anything else locally.

## 1. System packages

Flutter's Linux desktop toolchain needs clang, CMake, Ninja, pkg-config, GTK 3 headers and the C++ standard library headers. The tray icon (`tray_manager`) also needs the X11 and Xi headers:

```bash
sudo dnf install -y git clang cmake ninja-build pkgconf-pkg-config gtk3-devel libstdc++-devel libX11-devel libXi-devel xz
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
flutter config --no-enable-android --no-enable-web
flutter doctor -v
```

`flutter doctor` should show a green check for **Linux toolchain**. It may warn about Android Studio, Chrome or Xcode, and you can ignore those.

## 3. Get the code and run it

```bash
gh repo clone Krkr8/taskwise
cd taskwise
flutter pub get
cd app
flutter run -d linux
```

## Troubleshooting: `flutter test` fails with "Building native assets failed"

The tray library compiles its native code when tests start. If your `PATH` contains Fedora's ccache wrappers (`/usr/lib64/ccache`, added by the `ccache` package), that build picks `ccache` itself as the compiler and fails. Run the tests without that folder on `PATH`:

```bash
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v ccache | paste -sd:) flutter test
```

`flutter build linux` and `flutter run -d linux` aren't affected (they use CMake).
