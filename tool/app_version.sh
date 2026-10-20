#!/usr/bin/env bash
# Prints the app version from app/pubspec.yaml without the build number,
# e.g. "0.1.0" for "version: 0.1.0+1". Used by packaging and release checks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sed -n 's/^version: *\([^+ ]*\).*/\1/p' "$ROOT/app/pubspec.yaml"
