#!/usr/bin/env bash
# Prints a SideStore/AltStore "source" for one release (M12), e.g.
#   tool/make_sidestore_source.sh 1.1.0 dist > dist/sidestore-source.json
# Its address stays the same for every release:
#   https://github.com/Krkr8/taskwise/releases/latest/download/sidestore-source.json
# Added once in SideStore (Sources → +), it lets SideStore update Taskwise on
# the iPhone (when SideStore's Apple sign-in works; see
# docs/install-ios-sidestore.md).
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <folder with the .ipa>" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$1"
IPA="$2/taskwise-$VERSION-ios-unsigned.ipa"
[[ -f "$IPA" ]] || { echo "error: $IPA missing" >&2; exit 1; }

NOTES="$("$ROOT/tool/changelog_section.sh" "$VERSION" 2>/dev/null || true)" \
SIZE="$(stat -c %s "$IPA")" VERSION="$VERSION" DATE="$(date -u +%Y-%m-%d)" \
python3 - <<'PY'
import json, os

repo = "https://github.com/Krkr8/taskwise"
version = os.environ["VERSION"]
print(json.dumps({
    "name": "Taskwise",
    "identifier": "io.github.krkr8.taskwise.source",
    "sourceURL": f"{repo}/releases/latest/download/sidestore-source.json",
    "website": repo,
    "apps": [{
        "name": "Taskwise",
        "bundleIdentifier": "io.github.krkr8.taskwise",
        "developerName": "Krkr8",
        "subtitle": "To-dos and reminders, synced through your own server.",
        "localizedDescription": "A to-do and reminders app with time and location reminders, Siri, English and Arabic, synced through your own free server.",
        "iconURL": "https://raw.githubusercontent.com/Krkr8/taskwise/main/app/linux/packaging/io.github.krkr8.taskwise.png",
        "tintColor": "#1F1F1F",
        "category": "productivity",
        "versions": [{
            "version": version,
            "date": os.environ["DATE"],
            "localizedDescription": os.environ.get("NOTES", "").strip(),
            "downloadURL": f"{repo}/releases/download/v{version}/taskwise-{version}-ios-unsigned.ipa",
            "size": int(os.environ["SIZE"]),
            "minOSVersion": "15.0",
        }],
        "appPermissions": {"entitlements": [], "privacy": {}},
    }],
    "news": [],
}, indent=2, ensure_ascii=False))
PY
