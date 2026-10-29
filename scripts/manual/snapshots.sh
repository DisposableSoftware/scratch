#!/usr/bin/env bash
# Renders the now-playing bar and the player, playing and failed, to PNGs for a look by eye
# (PLAY-2, PLAY-3, PLAY-8), and the settings sheet and the failed player in each flavour with an
# accent (LOOK-2 to LOOK-5). ImageRenderer draws some controls as placeholders. The bar draws no
# background of its own, since in the app the tab view's bottom accessory supplies it, so its
# render shows content only.
# Usage: scripts/manual/snapshots.sh [OUT_DIR]   (defaults to build/snapshots)
set -euo pipefail
cd "$(dirname "$0")/../.."
out=$(mkdir -p "${1:-build/snapshots}" && cd "${1:-build/snapshots}" && pwd)
TEST_RUNNER_SCRATCH_SNAPSHOTS=$out xcodebuild -project Scratch.xcodeproj -scheme Scratch \
  -destination "platform=iOS Simulator,name=${SCRATCH_SIMULATOR:-iPhone 17}" \
  -collect-test-diagnostics never -only-testing:ScratchTests/SnapshotTests test 2>&1 | { grep -E '✔ Test|✘|error:' || true; }
ls "$out"/*.png
