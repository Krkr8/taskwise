#!/usr/bin/env bash
# Builds the whole site (home pages + Flutter web app) into <out_dir>.
# Usage: web/build_site.sh <version> <out_dir>
set -euo pipefail
version="${1:?usage: build_site.sh <version> <out_dir>}"
out="${2:?usage: build_site.sh <version> <out_dir>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like 1.2.3, got '$version'" >&2; exit 1; }
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null)" || { echo "error: not a git checkout" >&2; exit 1; }

# Resolve <out_dir> to an absolute path WITHOUT creating it, and refuse dangerous
# targets (the repo root or anything inside it, /, $HOME, any parent of the repo
# root) before anything is created or deleted.
root_real="$(cd "$root" && pwd -P)"
out_parent="$(dirname "$out")"
[ -d "$out_parent" ] || { echo "error: parent of $out does not exist" >&2; exit 1; }
if [ -d "$out" ]; then
  out="$(cd "$out" && pwd -P)"
else
  out="$(cd "$out_parent" && pwd -P)/$(basename "$out")"
fi
home_real="$(cd "$HOME" && pwd -P)"
case "$out" in
  /|"$home_real"|"$HOME"|"$root_real"|"$root_real"/*)
    echo "error: refusing to use $out as the output directory (repo root or inside it, /, or \$HOME)" >&2; exit 1 ;;
esac
case "$root_real/" in
  "$out"/*) echo "error: refusing to use $out (it contains the repository)" >&2; exit 1 ;;
esac
# The folder is deleted and rebuilt: only an empty one, or one this script
# built before (it has the marker file), so a typo can't delete e.g. ~/Downloads.
marker=".taskwise-site"
if [ -e "$out" ] && [ ! -d "$out" ]; then
  echo "error: $out exists and is not a directory" >&2; exit 1
fi
if [ -d "$out" ] && [ -n "$(ls -A "$out")" ] && [ ! -f "$out/$marker" ]; then
  echo "error: refusing to delete $out: it isn't empty and wasn't built by this script (no $marker file). Pick a new or empty folder." >&2
  exit 1
fi

(cd "$root/app" && flutter build web --release --base-href /app/ --pwa-strategy=none)

rm -rf "$out"
mkdir -p "$out"
echo "Built by web/build_site.sh, which deletes this folder on its next run." > "$out/$marker"
mkdir -p "$out/app" "$out/fonts"
cp -r "$root/web/site/." "$out/"
cp -r "$root/app/build/web/." "$out/app/"
cp "$root/app/web/icons/favicon-48.png" "$out/favicon.png"
for f in SpaceGrotesk-Regular SpaceGrotesk-Medium SpaceGrotesk-Bold \
  IBMPlexSansArabic-Regular IBMPlexSansArabic-Medium IBMPlexSansArabic-Bold; do
  cp "$root/app/assets/fonts/$f.ttf" "$out/fonts/"
done
cp "$root/app/assets/fonts/OFL-SpaceGrotesk.txt" "$root/app/assets/fonts/OFL-IBMPlexSansArabic.txt" "$out/fonts/"

# Flutter writes an empty service worker even with --pwa-strategy=none; ours is sw.js.
rm -f "$out/app/flutter_service_worker.js"

# Home pages: the plain version. Service worker: version + commit, so a redeploy
# of the same version still changes sw.js and installs a new worker.
sed -i "s/{{VERSION}}/$version/g" "$out/index.html" "$out/ar/index.html"
sed -i "s/{{VERSION}}/$version-$commit/g" "$out/app/sw.js"
echo "Site for $version ($commit) built in $out"
