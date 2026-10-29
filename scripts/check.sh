#!/usr/bin/env bash
# The one gate before every code commit and release (TOOL-10). /implement, /release and
# scripts/release.sh run it. Add the project's build, lint and test commands at the end.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/spec-lint.sh
scripts/test-tooling.sh

scripts/arch-lint.sh
scripts/test-arch-lint.sh >/dev/null

# Build and run the unit tests on an iOS 27 simulator. Set SCRATCH_SIMULATOR to use another device.
# The grep drops Xcode 27.1 log noise; pipefail keeps xcodebuild's exit status.
xcodebuild -project Scratch.xcodeproj -scheme Scratch \
  -destination "platform=iOS Simulator,name=${SCRATCH_SIMULATOR:-iPhone 17}" \
  -quiet test 2>&1 | { grep -vE 'IDESchemeActionSDKRecord|IDETestOperationsObserverDebug|^Testing started$' || true; }
