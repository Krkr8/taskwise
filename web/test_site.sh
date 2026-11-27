#!/usr/bin/env bash
# Checks a built site (output of build_site.sh). Usage: web/test_site.sh <out_dir>
set -u
out="${1:?usage: test_site.sh <out_dir>}"
fail=0
bad() { echo "FAIL: $*"; fail=1; }

for f in index.html ar/index.html style.css app/index.html app/sw.js app/sqlite3.wasm vercel.json \
  fonts/SpaceGrotesk-Bold.ttf fonts/IBMPlexSansArabic-Regular.ttf; do
  [ -f "$out/$f" ] || bad "missing $f"
done
[ -e "$out/app/flutter_service_worker.js" ] && bad "app/flutter_service_worker.js should be deleted"

if [ -d "$out" ]; then
  left=$(grep -rl '{{VERSION}}' "$out" 2>/dev/null || true)
  [ -z "$left" ] || bad "{{VERSION}} left in: $left"
fi

# Download links: all must match the release asset pattern, same version everywhere.
version=""
for page in index.html ar/index.html; do
  [ -f "$out/$page" ] || continue
  links=$(grep -o 'https://github.com/Krkr8/taskwise/releases/download/[^"]*' "$out/$page" || true)
  n=$(printf '%s\n' "$links" | grep -c . || true)
  [ "$n" -eq 5 ] || bad "$page: expected 5 download links, found $n"
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    if [[ "$l" =~ ^https://github\.com/Krkr8/taskwise/releases/download/v([0-9]+\.[0-9]+\.[0-9]+)/taskwise-([0-9]+\.[0-9]+\.[0-9]+)-(windows-x64\.zip|linux-x86_64\.AppImage|linux-x64\.tar\.gz|android\.apk|ios-unsigned\.ipa)$ ]]; then
      [ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ] || bad "$page: version mismatch in $l"
      [ -z "$version" ] && version="${BASH_REMATCH[1]}"
      [ "$version" = "${BASH_REMATCH[1]}" ] || bad "$page: different version in $l"
    else
      bad "$page: bad download link $l"
    fi
  done <<< "$links"
  grep -q 'docs/self-hosting.md' "$out/$page" || bad "$page: no self-hosting link"
  grep -q 'docs/install-ios-sidestore.md' "$out/$page" || bad "$page: no iOS install link"
  grep -q 'href="/app/"' "$out/$page" || bad "$page: no link to /app/"
  # Nothing from third parties: only github.com links allowed as absolute URLs.
  ext=$(grep -oE '(src|href)="https?://[^"]*"' "$out/$page" | grep -v 'https://github.com/Krkr8/taskwise' || true)
  [ -z "$ext" ] || bad "$page: third-party URL: $ext"
done
grep -q 'dir="rtl"' "$out/ar/index.html" 2>/dev/null || bad "ar/index.html is not rtl"

# sw.js cache name: <version>-<commit>
if [ -f "$out/app/sw.js" ]; then
  grep -Eq "CACHE_VERSION = '[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]+'" "$out/app/sw.js" || bad "sw.js CACHE_VERSION not set to <version>-<commit>"
fi

# vercel.json
if [ -f "$out/vercel.json" ]; then
  python3 - "$out/vercel.json" <<'PY' || fail=1
import json, sys
try:
    j = json.load(open(sys.argv[1]))
except Exception as e:
    print("FAIL: vercel.json invalid:", e); sys.exit(1)
ok = True
def hdrs(src):
    return {h["key"]: h["value"] for r in j.get("headers", []) if r["source"] == src for h in r["headers"]}
a = hdrs("/app/(.*)")
if a.get("Cross-Origin-Opener-Policy") != "same-origin": print("FAIL: COOP"); ok = False
if a.get("Cross-Origin-Embedder-Policy") != "credentialless": print("FAIL: COEP"); ok = False
for s in ["/app/index.html", "/app/flutter_bootstrap.js", "/app/sw.js", "/app/manifest.json", "/index.html", "/ar/index.html"]:
    if hdrs(s).get("Cache-Control") != "no-cache": print("FAIL: no-cache for", s); ok = False
if "immutable" in json.dumps(j): print("FAIL: immutable must not be used"); ok = False
if not j.get("cleanUrls"): print("FAIL: cleanUrls"); ok = False
if not any(r["source"] in ("/app", "/app$") and r["destination"] == "/app/" for r in j.get("redirects", [])): print("FAIL: /app redirect"); ok = False
sys.exit(0 if ok else 1)
PY
fi

[ $fail -eq 0 ] && echo "site OK" || { echo "site check FAILED"; exit 1; }
