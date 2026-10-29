#!/usr/bin/env bash
# Renders the now-playing bar and the player, playing and failed, to PNGs for a look by eye
# (PLAY-2, PLAY-3, PLAY-8). ImageRenderer draws some controls as placeholders.
# Usage: scripts/manual/snapshots.sh [OUT_DIR]   (defaults to build/snapshots)
set -euo pipefail
cd "$(dirname "$0")/../.."
out=$(mkdir -p "${1:-build/snapshots}" && cd "${1:-build/snapshots}" && pwd)
TEST_RUNNER_SCRATCH_SNAPSHOTS=$out xcodebuild -project Scratch.xcodeproj -scheme Scratch \
  -destination "platform=iOS Simulator,name=${SCRATCH_SIMULATOR:-iPhone 17}" \
  -only-testing:ScratchTests/SnapshotTests test 2>&1 | { grep -E '✔ Test|✘|error:' || true; }
ls "$out"/*.png
