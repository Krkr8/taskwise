#!/usr/bin/env bash
# Packages a release build of the Linux app as
#   dist/taskwise-<version>-linux-x64.tar.gz
# Run `flutter build linux --release` in app/ first. Used by CI and locally.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$("$ROOT/tool/app_version.sh")"
NAME="taskwise-$VERSION-linux-x64"
BUNDLE="$ROOT/app/build/linux/x64/release/bundle"
PACKAGING="$ROOT/app/linux/packaging"
STAGE="$ROOT/dist/$NAME"

[[ -x "$BUNDLE/taskwise" ]] || {
  echo "error: $BUNDLE/taskwise missing; run 'flutter build linux --release' in app/" >&2
  exit 1
}

rm -rf "$STAGE" "$ROOT/dist/$NAME.tar.gz"
mkdir -p "$STAGE"
cp -r "$BUNDLE" "$STAGE/bundle"
cp "$PACKAGING/install.sh" \
  "$PACKAGING/io.github.krkr8.taskwise.desktop" \
  "$PACKAGING/io.github.krkr8.taskwise.png" "$STAGE/"
tar -C "$ROOT/dist" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
rm -rf "$STAGE"
echo "$ROOT/dist/$NAME.tar.gz"
