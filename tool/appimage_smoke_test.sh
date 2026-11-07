#!/usr/bin/env bash
# Checks that the Taskwise AppImage starts on other distributions, using
# podman containers (no root needed):
#
#   tool/appimage_smoke_test.sh dist/taskwise-<version>-linux-x86_64.AppImage [image ...]
#
# Default images: debian:12 ubuntu:22.04 ubuntu:24.04 archlinux. Each one
# gets a plain GTK 3 and Mesa (EGL) install, what any GTK desktop has, and
# Xvfb. Then:
#   1. every library in the AppImage must resolve (`ldd`, no "not found");
#   2. Taskwise must start in a virtual display, stay up for 15 seconds and
#      write its "started" line to the log.
set -euo pipefail

APPIMAGE="$(readlink -f "${1:?usage: $0 <file.AppImage> [image ...]}")"
shift
IMAGES=("$@")
[[ ${#IMAGES[@]} -gt 0 ]] || IMAGES=(debian:12 ubuntu:22.04 ubuntu:24.04 archlinux)

read -r -d '' CHECK <<'EOF' || true
set -eu
cp /in/app.AppImage /tmp/app.AppImage
cd /tmp && ./app.AppImage --appimage-extract >/dev/null
# libdartjni is only loaded on Android (it needs a Java VM).
# Each library is checked on its own, as the dynamic loader sees it.
missing="$(for f in squashfs-root/usr/bin/taskwise squashfs-root/usr/bin/lib/*.so*; do
  case "$f" in */libdartjni.so) continue ;; esac
  ldd "$f" | grep 'not found' | sed "s|^|$(basename "$f"): |"
done)"
if [ -n "$missing" ]; then echo "MISSING LIBRARIES:"; echo "$missing"; exit 1; fi
export HOME=/tmp/home && mkdir -p "$HOME"
# Without FUSE in the container, the runtime extracts itself and runs.
export APPIMAGE_EXTRACT_AND_RUN=1
dbus-run-session -- xvfb-run -a ./app.AppImage >/tmp/out.txt 2>&1 &
sleep 15
if ! pgrep -x taskwise >/dev/null; then
  echo "TASKWISE EXITED:"; tail -30 /tmp/out.txt; exit 1
fi
log="$(find "$HOME" -name taskwise.log | head -1)"
[ -n "$log" ] || { echo "NO LOG FILE:"; tail -30 /tmp/out.txt; exit 1; }
grep -q 'started on linux' "$log" || { echo "NO STARTUP LINE"; cat "$log"; exit 1; }
grep 'started on linux' "$log" | tail -1
EOF

install_cmd() {
  case "$1" in
    debian:* | ubuntu:*)
      echo 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq libgtk-3-0 libegl1 libgles2 libgl1-mesa-dri xvfb xauth dbus procps file >/dev/null' ;;
    archlinux*)
      echo 'pacman -Sy --noconfirm --needed gtk3 xorg-server-xvfb xorg-xauth dbus procps-ng file >/dev/null' ;;
    *) echo "error: no install command for $1" >&2; exit 1 ;;
  esac
}

failed=()
for image in "${IMAGES[@]}"; do
  echo "=== $image"
  if podman run --rm -v "$APPIMAGE:/in/app.AppImage:ro,Z" "$image" \
    sh -c "$(install_cmd "$image") && $CHECK"; then
    echo "--- $image: OK"
  else
    echo "--- $image: FAILED"
    failed+=("$image")
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed on: ${failed[*]}"
  exit 1
fi
echo "AppImage works on: ${IMAGES[*]}"
