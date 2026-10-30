#!/usr/bin/env bash
# Installs Taskwise for the current user (no sudo needed), or removes it.
#
#   ./install.sh              install or update
#   ./install.sh --uninstall  remove the app (your tasks are kept)
#
# Run it from the extracted release folder.
set -euo pipefail

APP_ID=io.github.krkr8.taskwise
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA_HOME/taskwise"
DESKTOP_FILE="$DATA_HOME/applications/$APP_ID.desktop"
ICON_FILE="$DATA_HOME/icons/hicolor/256x256/apps/$APP_ID.png"
USER_DATA="$DATA_HOME/$APP_ID"

refresh_caches() {
  update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true
  gtk-update-icon-cache -q -t "$DATA_HOME/icons/hicolor" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -rf "$DEST"
  rm -f "$DESKTOP_FILE" "$ICON_FILE"
  refresh_caches
  echo "Taskwise was removed."
  echo "Your tasks are still in $USER_DATA (delete that folder to erase them)."
  exit 0
fi

if [[ ! -x "$HERE/bundle/taskwise" ]]; then
  echo "error: bundle/taskwise not found next to this script." >&2
  echo "Run install.sh from inside the extracted Taskwise folder." >&2
  exit 1
fi

# Replace any previous version in one go.
rm -rf "$DEST"
mkdir -p "$DEST"
cp -r "$HERE/bundle/." "$DEST/"

install -Dm644 "$HERE/$APP_ID.png" "$ICON_FILE"
mkdir -p "$(dirname "$DESKTOP_FILE")"
sed "s|^Exec=@EXEC@$|Exec=$DEST/taskwise|" "$HERE/$APP_ID.desktop" > "$DESKTOP_FILE"
refresh_caches

echo "Taskwise is installed in $DEST"
echo "Open it from Activities (search for \"Taskwise\"), or run: $DEST/taskwise"
