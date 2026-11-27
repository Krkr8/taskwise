#!/usr/bin/env bash
# Builds the whole site (home pages + Flutter web app) into <out_dir>.
# Usage: web/build_site.sh <version> <out_dir>
set -euo pipefail
version="${1:?usage: build_site.sh <version> <out_dir>}"
out="${2:?usage: build_site.sh <version> <out_dir>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

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
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo local)"
sed -i "s/{{VERSION}}/$version/g" "$out/index.html" "$out/ar/index.html"
sed -i "s/{{VERSION}}/$version-$commit/g" "$out/app/sw.js"
echo "Site for $version ($commit) built in $out"
