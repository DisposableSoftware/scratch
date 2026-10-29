#!/usr/bin/env bash
# Names a project made from the template (TOOL-9): replaces the template's name in every
# tracked file, removes the template-only README sections, drops TOOL-9, and deletes itself.
# Usage: scripts/init.sh "My Project"
set -euo pipefail
cd "$(dirname "$0")/.."

[ $# = 1 ] && [ -n "$1" ] || { echo "usage: $0 \"Project Name\"" >&2; exit 2; }
export NEW_NAME=$1

# Skips this script: bash reads it while it runs, so rewriting it here would corrupt the run.
git ls-files | while read -r f; do
  [ "$f" != scripts/init.sh ] && grep -qF "Template Project" "$f" || continue
  perl -pi -e 's/\QTemplate Project\E/$ENV{NEW_NAME}/g' "$f"
done
perl -0pi -e 's/\n?<!-- template:begin -->.*?<!-- template:end -->\n?//gs' README.md
perl -pi -e 's/^(\| `TOOL-9` \|.*?\| )done( \|.*)$/$1dropped: the project was initialised and the script removed$2/' spec/tooling.md
perl -pi -e 's/^(scripts\/init\.sh .*\n)//' CLAUDE.md
git rm -q scripts/init.sh

git config core.hooksPath .githooks
echo "Named the project $NEW_NAME. Review with git diff, then commit."
