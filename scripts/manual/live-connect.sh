#!/usr/bin/env bash
# Checks SRV-3 and SRV-5 against a real server, in the simulator only.
#   SRV-3: a wrong password, a web page and a closed port each fail with their own error, and the
#          right credentials connect and save the server.
#   SRV-5: launching the app afterwards opens the library, not setup (screenshot).
#   LIB-1, LIB-5: that library lists the server's tracks with title, artist, album, duration and art.
# Credentials come from the environment and are never written anywhere:
#   SCRATCH_SERVER=… SCRATCH_USER=… SCRATCH_PASSWORD=… scripts/manual/live-connect.sh [OUT_DIR]
# Set SCRATCH_SIMULATOR to use another device than "iPhone 17". The app is uninstalled from that
# simulator before and after, so any data it had there is lost.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${SCRATCH_SERVER:?set SCRATCH_SERVER}" "${SCRATCH_USER:?set SCRATCH_USER}" "${SCRATCH_PASSWORD:?set SCRATCH_PASSWORD}"
device=${SCRATCH_SIMULATOR:-iPhone 17}
out=${1:-build/manual}
mkdir -p "$out"

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
# Start from a clean app: no saved server.
xcrun simctl uninstall "$device" lol.weston.scratch 2>/dev/null || true

# Diagnostics collection is off: after a passing run xcodebuild has sat in `simctl diagnose` for
# its full ten minutes, which looked like a hung script.
# xcodebuild hands TEST_RUNNER_-prefixed variables to the test process without the prefix.
TEST_RUNNER_SCRATCH_SERVER=$SCRATCH_SERVER TEST_RUNNER_SCRATCH_USER=$SCRATCH_USER TEST_RUNNER_SCRATCH_PASSWORD=$SCRATCH_PASSWORD \
  xcodebuild -project Scratch.xcodeproj -scheme Scratch -destination "platform=iOS Simulator,name=$device" \
  -derivedDataPath build -collect-test-diagnostics never -only-testing:ScratchTests/LiveServerTests test 2>&1 |
  { grep -E '✔|✘|passed|failed|error:' || true; } | { grep -v IDESchemeActionSDKRecord || true; }

# The test run left the saved server in the app's container; launching should go to the library.
xcrun simctl launch "$device" lol.weston.scratch >/dev/null
sleep 8
xcrun simctl io "$device" screenshot "$out/srv5-relaunch.png" >/dev/null 2>&1
echo "screenshot: $out/srv5-relaunch.png (expect the library, not setup)"

# Leave no signed-in app behind: unit tests run inside it, and must never reach a real server.
xcrun simctl terminate "$device" lol.weston.scratch 2>/dev/null || true
xcrun simctl uninstall "$device" lol.weston.scratch
