#!/usr/bin/env bash
# Signs a folder of release files for Taskwise's in-app updates (M12):
#   UPDATE_SIGNING_KEY="$(cat key.pem)" tool/sign_release.sh dist
# writes dist/SHA256SUMS (every file in the folder) and dist/SHA256SUMS.sig
# (its raw Ed25519 signature), then checks the signature against the public
# key built into the app (app/lib/update/update_key.dart), so a release
# signed with the wrong key fails here instead of on people's devices.
# The private key never touches the disk outside a private temp file.
set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo "usage: UPDATE_SIGNING_KEY=<PEM> $0 <folder>" >&2
  exit 2
fi
if [[ -z "${UPDATE_SIGNING_KEY:-}" ]]; then
  echo "error: UPDATE_SIGNING_KEY is empty (the GitHub secret is missing?)" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$1"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
chmod 700 "$work"
printf '%s\n' "$UPDATE_SIGNING_KEY" > "$work/key.pem"

rm -f "$DIR/SHA256SUMS" "$DIR/SHA256SUMS.sig"
# The glob is expanded before the redirect creates SHA256SUMS.
(cd "$DIR" && sha256sum -- * > SHA256SUMS)
openssl pkeyutl -sign -inkey "$work/key.pem" -rawin \
  -in "$DIR/SHA256SUMS" -out "$DIR/SHA256SUMS.sig"

# The app's public key: raw 32 bytes (base64) → an SPKI DER for openssl.
public="$(sed -n "s/^  defaultValue: '\([A-Za-z0-9+/=]*\)',$/\1/p" \
  "$ROOT/app/lib/update/update_key.dart" | head -n 1)"
[[ -n "$public" ]] || { echo "error: no public key in update_key.dart" >&2; exit 1; }
{ printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00'; printf '%s' "$public" | base64 -d; } \
  > "$work/public.der"
if ! openssl pkeyutl -verify -pubin -inkey "$work/public.der" -keyform DER -rawin \
  -in "$DIR/SHA256SUMS" -sigfile "$DIR/SHA256SUMS.sig" >/dev/null; then
  echo "error: the signing key doesn't match the public key in update_key.dart" >&2
  exit 1
fi
echo "Signed $(wc -l < "$DIR/SHA256SUMS") files in $DIR/SHA256SUMS"
