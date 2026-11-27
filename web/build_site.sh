#!/usr/bin/env bash
# Builds the whole site (home pages + Flutter web app) into <out_dir>.
# Usage: web/build_site.sh <version> <out_dir>
set -euo pipefail
version="${1:?usage: build_site.sh <version> <out_dir>}"
out="${2:?usage: build_site.sh <version> <out_dir>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like 1.2.3, got '$version'" >&2; exit 1; }
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null)" || { echo "error: not a git checkout" >&2; exit 1; }

# Resolve <out_dir> to an absolute path and refuse dangerous targets before any rm -rf.
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root_real="$(cd "$root" && pwd -P)"
case "$out" in
  /|"$HOME"|"$root_real"|"$root_real/app/build/web"|"$root_real/app/build"|"$root_real/app")
    echo "error: refusing to use $out as the output directory" >&2; exit 1 ;;
esac
case "$root_real/" in
  "$out"/*) echo "error: refusing to use $out (it contains the repository)" >&2; exit 1 ;;
esac

(cd "$root/app" && flutter build web --release --base-href /app/ --pwa-strategy=none)

rm -rf "$out"
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
