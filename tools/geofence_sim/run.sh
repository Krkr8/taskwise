#!/usr/bin/env bash
# Location-reminder checks with Swift in a podman container (no Swift or
# Mac needed on the laptop):
#   tools/geofence_sim/run.sh             walk simulator, all scenarios
#   tools/geofence_sim/run.sh trace 4 7   event log of scenario 4, seed 7
#   tools/geofence_sim/run.sh test        the Swift unit tests (RunnerTests)
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "${1:-}" == "test" ]]; then
  # A throwaway Swift package with the platform-free code and its tests.
  script='
    set -eo pipefail
    mkdir -p /pkg/Sources/Runner /pkg/Tests/RunnerTests
    cp app/ios/Runner/GeofenceDecider.swift /pkg/Sources/Runner/
    cp app/ios/RunnerTests/RunnerTests.swift /pkg/Tests/RunnerTests/
    cat > /pkg/Package.swift <<PKG
// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "Runner", targets: [
  .target(name: "Runner"),
  .testTarget(name: "RunnerTests", dependencies: ["Runner"]),
])
PKG
    cd /pkg && swift test 2>&1 | grep -vE "^\[[0-9]+/[0-9]+\]|^Building|^Build complete|^Compiling|^Write"'
else
  script="swiftc -O app/ios/Runner/GeofenceDecider.swift tools/geofence_sim/main.swift -o /tmp/sim && /tmp/sim $*"
fi
if command -v swiftc >/dev/null; then
  # Swift is installed (e.g. the CI job's Swift container).
  cd "$root" && bash -c "${script//\/src/$root}"
else
  podman run --rm -v "$root:/src:Z" -w /src docker.io/library/swift:6.1 bash -c "$script"
fi
