#!/usr/bin/env bash
# Packages a release build of the Linux app as an AppImage:
#   dist/taskwise-<version>-linux-x86_64.AppImage
# Run `flutter build linux --release` in app/ first. Used by CI and locally.
#
# The AppImage carries the Flutter bundle plus the few libraries a desktop
# may not have installed (see BUNDLE_LIBS). It relies on the system for the
# rest: glibc, GTK 3 and the graphics stack, which every GTK desktop has. It
# is built on Ubuntu 22.04 in CI, so it runs on distributions with glibc
# 2.35 or newer (Debian 12+, Ubuntu 22.04+, Arch, Fedora 36+).
#
# appimagetool and the AppImage runtime are pinned releases, checked against
# their SHA-256 sums, and cached in build/appimage-tools/. Needs patchelf
# (`sudo dnf install patchelf` / `sudo apt install patchelf`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$("$ROOT/tool/app_version.sh")"
APP_ID=io.github.krkr8.taskwise
BUNDLE="$ROOT/app/build/linux/x64/release/bundle"
PACKAGING="$ROOT/app/linux/packaging"
OUT="$ROOT/dist/taskwise-$VERSION-linux-x86_64.AppImage"
APPDIR="$ROOT/build/appimage/Taskwise.AppDir"
TOOLS="$ROOT/build/appimage-tools"

APPIMAGETOOL_URL=https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage
APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0
RUNTIME_URL=https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64
RUNTIME_SHA256=2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d

# Libraries copied from the build machine into the AppImage. libsecret
# (sign-in token storage, flutter_secure_storage) is missing on some
# minimal and non-GNOME installs. The tray icon talks to the desktop over
# D-Bus directly and needs no appindicator library.
BUNDLE_LIBS=(libsecret-1.so.0)

command -v patchelf >/dev/null || {
  echo "error: patchelf is missing (sudo dnf install patchelf / sudo apt install patchelf)" >&2
  exit 1
}
[[ -x "$BUNDLE/taskwise" ]] || {
  echo "error: $BUNDLE/taskwise missing; run 'flutter build linux --release' in app/" >&2
  exit 1
}

fetch() { # url sha256 destination
  if [[ ! -f "$3" ]] || ! echo "$2  $3" | sha256sum -c --quiet - 2>/dev/null; then
    mkdir -p "$(dirname "$3")"
    curl -fsSL --retry 3 -o "$3.part" "$1"
    echo "$2  $3.part" | sha256sum -c --quiet - || {
      echo "error: checksum mismatch for $1" >&2
      exit 1
    }
    mv "$3.part" "$3"
  fi
  chmod +x "$3"
}
fetch "$APPIMAGETOOL_URL" "$APPIMAGETOOL_SHA256" "$TOOLS/appimagetool"
fetch "$RUNTIME_URL" "$RUNTIME_SHA256" "$TOOLS/runtime-x86_64"

rm -rf "$APPDIR" "$OUT"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# The Flutter bundle as built: the binary finds lib/ and data/ next to
# itself (RPATH $ORIGIN/lib).
cp -r "$BUNDLE/." "$APPDIR/usr/bin/"

for lib in "${BUNDLE_LIBS[@]}"; do
  path="$(ldconfig -p | awk -v l="$lib" '$1 == l && /x86-64/ {print $NF}' | sed -n 1p)"
  [[ -n "$path" ]] || {
    echo "error: $lib not found on the build machine" >&2
    exit 1
  }
  cp -L "$path" "$APPDIR/usr/bin/lib/$lib"
done

# Plugins load their own libraries (e.g. libsecret), and their RUNPATH
# points at the build machine's folder. Make every bundled library look
# next to itself first, so the copies above are found.
for so in "$APPDIR"/usr/bin/lib/*.so*; do
  patchelf --set-rpath '$ORIGIN' "$so"
done

sed "s|^Exec=@EXEC@$|Exec=taskwise|" "$PACKAGING/$APP_ID.desktop" \
  > "$APPDIR/usr/share/applications/$APP_ID.desktop"
cp "$APPDIR/usr/share/applications/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
cp "$PACKAGING/$APP_ID.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/"
cp "$PACKAGING/$APP_ID.png" "$APPDIR/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
# Starts Taskwise from inside the mounted AppImage.
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/taskwise" "$@"
EOF
chmod +x "$APPDIR/AppRun"

mkdir -p "$ROOT/dist"
# --appimage-extract-and-run: works in containers and CI without FUSE.
ARCH=x86_64 "$TOOLS/appimagetool" --appimage-extract-and-run \
  --no-appstream --runtime-file "$TOOLS/runtime-x86_64" \
  "$APPDIR" "$OUT" >&2
echo "$OUT"
