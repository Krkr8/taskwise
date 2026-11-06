#!/usr/bin/env bash
# Prints the CHANGELOG.md section of one version (without its heading), e.g.
#   tool/changelog_section.sh 0.5.0
# Used by the release workflow as the text of the draft GitHub release.
# Exits with an error and prints nothing if the version has no section or
# the section is empty.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version>   (for example 0.5.0, without the v)" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

section="$(awk -v version="$1" '
  # A "## [" heading starts a section; the link list at the bottom ends it.
  /^## \[/ { in_section = (index($0, "## [" version "]") == 1); next }
  /^\[[^]]+\]: / { in_section = 0 }
  in_section { print }
' "$ROOT/CHANGELOG.md")"

# Trim blank lines at the start and the end.
section="$(printf '%s\n' "$section" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [[ -z "$section" ]]; then
  echo "error: no entry for version $1 in CHANGELOG.md" >&2
  exit 1
fi
printf '%s\n' "$section"
