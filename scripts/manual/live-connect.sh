#!/usr/bin/env bash
# Checks SRV-3 and SRV-5 against a real server, in the simulator only.
#   SRV-3: a wrong password, a web page and a closed port each fail with their own error, and the
#          right credentials connect and save the server.
#   SRV-5: launching the app afterwards opens the library, not setup (screenshot).
#   ALB-9 to ALB-12: an album's tracks in disc order, and screenshots of its screen (alb9-*.png).
#   ALB-17, ALB-18: the Albums grid at 5, 1 and 2 per row, from the saved setting.
#   LIB-1, LIB-5: that library lists the server's tracks with title, artist, album, duration and art.
# Credentials come from the environment and are never written anywhere:
#   SCRATCH_SERVER=… SCRATCH_USER=… SCRATCH_PASSWORD=… scripts/manual/live-connect.sh [OUT_DIR]
# Navidrome allows only a few failed sign-ins in a short window (five in twenty seconds by default),
# and the suite makes three on purpose. Run it again within twenty seconds and a valid sign-in may be
# turned away with "wrong username or password"; wait and rerun.
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
  TEST_RUNNER_SCRATCH_SNAPSHOT_DIR=$(cd "$out" && pwd) \
  xcodebuild -project Scratch.xcodeproj -scheme Scratch -destination "platform=iOS Simulator,name=$device" \
  -derivedDataPath build -collect-test-diagnostics never -only-testing:ScratchTests/LiveServerTests test 2>&1 |
  { grep -E '✔|✘|passed|failed|error:' || true; } | { grep -v IDESchemeActionSDKRecord || true; }

# The test run left the saved server in the app's container; launching should go to the library.
xcrun simctl launch "$device" lol.weston.scratch >/dev/null
sleep 8
xcrun simctl io "$device" screenshot "$out/srv5-relaunch.png" >/dev/null 2>&1
echo "screenshot: $out/srv5-relaunch.png (expect the library, not setup)"

# ALB-17, ALB-18: the grid at 5, 1 and 2 per row, read from the setting at launch. A `-key value`
# launch argument stands in for the saved setting for that launch.
for per_row in 5 1 2; do
  xcrun simctl terminate "$device" lol.weston.scratch 2>/dev/null || true
  xcrun simctl launch "$device" lol.weston.scratch -settings.albumsPerRow "$per_row" >/dev/null
  sleep 6
  xcrun simctl io "$device" screenshot "$out/alb17-$per_row-per-row.png" >/dev/null 2>&1
done
echo "screenshots: $out/alb17-{5,1,2}-per-row.png (expect that many covers per row)"

# Leave no signed-in app behind: unit tests run inside it, and must never reach a real server.
xcrun simctl terminate "$device" lol.weston.scratch 2>/dev/null || true
xcrun simctl uninstall "$device" lol.weston.scratch
