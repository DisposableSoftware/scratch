#!/usr/bin/env bash
# The one gate before every code commit and release (TOOL-10). /implement, /release and
# scripts/release.sh run it. Add the project's build, lint and test commands at the end.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/spec-lint.sh
scripts/test-tooling.sh

# Project checks. For example:
#   cargo clippy --all-targets -- -D warnings && cargo test
#   npm run lint && npm test
#   ruff check . && pytest
