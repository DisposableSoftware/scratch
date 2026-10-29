#!/usr/bin/env bash
# Bumps the version, runs the checks, commits "Scratch X.Y.Z" and tags vX.Y.Z (TOOL-7).
# Does not push. Writes draft release notes to NOTES_FILE for `gh release create -F`.
# Usage: scripts/release.sh patch|minor|major|X.Y.Z NOTES_FILE
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Scratch"

# Writes the new version everywhere the project keeps it. Add lines here when the stack keeps
# it in its own manifest too (package.json, Cargo.toml, pyproject.toml).
set_version() {
  printf '%s\n' "$1" >VERSION
}

[ $# = 2 ] || { echo "usage: $0 patch|minor|major|X.Y.Z NOTES_FILE" >&2; exit 2; }
git diff --quiet && git diff --cached --quiet || { echo "working tree is dirty" >&2; exit 1; }

old=$(tr -d '[:space:]' <VERSION)
IFS=. read -r major minor patch <<<"$old"
case $1 in
  major) new="$((major + 1)).0.0" ;;
  minor) new="$major.$((minor + 1)).0" ;;
  patch) new="$major.$minor.$((patch + 1))" ;;
  [0-9]*.[0-9]*.[0-9]*) new=$1 ;;
  *) echo "bad level: $1" >&2; exit 2 ;;
esac
git rev-parse -q --verify "refs/tags/v$new" >/dev/null && { echo "v$new already exists" >&2; exit 1; }
prev=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
ids=$(scripts/release-check.sh | tail -n +2 | grep -E '^[A-Z]+-[0-9]+ is now (done|partial)' | cut -d' ' -f1 || true)

set_version "$new"
scripts/check.sh >/dev/null 2>&1 || { git checkout -- .; echo "scripts/check.sh failed; version left at $old" >&2; exit 1; }

git commit -q -am "$NAME $new"
git tag -a "v$new" -m "$NAME $new"

changes=$(
  if [ -n "$prev" ]; then
    for id in $ids; do
      row=$(grep -h "^| \`$id\` | " spec/*.md | head -1 | awk -F' [|] ' '{print $2}')
      echo "- \`$id\`: $row"
    done
    git log --format='- %s' "$prev..v$new^" | grep -v -e '^- spec: ' -e "^- $NAME [0-9]" || true
  else
    echo "- First release."
  fi
)
cat >"$2" <<NOTES
> [!WARNING]
> **Certified, artisanal, vibe-coded slop.** An AI wrote all of it while a person said "yeah, looks good" and pressed Enter a lot.

## Changes

$changes
NOTES
echo "v$new"
