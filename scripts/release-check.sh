#!/usr/bin/env bash
# Recommends a semantic version bump for the commits since the last v* tag (TOOL-6).
# Prints the level (none, patch, minor or major) on the first line, then the reasons.
#   major: a commit says BREAKING, or a requirement that had shipped is now dropped
#   minor: a requirement became done or partial (new behaviour shipped)
#   patch: anything else changed outside the paths in NOT_SHIPPED
#   none:  only spec, docs or tooling changed
# Usage: scripts/release-check.sh [REV]   (REV defaults to HEAD)
set -euo pipefail
cd "$(dirname "$0")/.."

# Paths that don't ship to users. Changes only here never need a release.
NOT_SHIPPED='^(spec/|docs/|scripts/|\.claude/|\.githooks/|CLAUDE\.md$|README\.md$|LICENSE$|\.gitignore$)'

rev=${1:-HEAD}
tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' "$rev" 2>/dev/null || true)
if [ -z "$tag" ]; then echo "minor"; echo "no v* tag yet"; exit 0; fi
if [ "$(git rev-list --count "$tag..$rev")" = 0 ]; then echo none; echo "nothing since $tag"; exit 0; fi

# "ID<TAB>status" for every requirement row in the spec at a revision.
requirements() {
  git ls-tree --name-only "$1" spec/ | grep -v -e '^spec/README.md$' -e '^spec/roadmap.md$' |
    while read -r f; do git show "$1:$f"; done | awk -f scripts/lib/spec-rows.awk | cut -f1,2 | sort -u
}

level=0 reasons=()
bump() { [ "$1" -gt "$level" ] && level=$1; reasons+=("$2"); }

if git log --format=%B "$tag..$rev" | grep -q 'BREAKING'; then bump 3 "a commit is marked BREAKING"; fi

old_rows=$(requirements "$tag")
while IFS=$'\t' read -r id st; do
  [ -n "$id" ] || continue
  old=$(echo "$old_rows" | awk -F'\t' -v i="$id" '$1 == i { print $2 }')
  case $st:$old in
    dropped:done | dropped:partial) bump 3 "$id is now dropped (was $old)" ;;
    done:done | done:partial | partial:done | partial:partial) ;;
    done:* | partial:*) bump 2 "$id is now $st (was ${old:-absent})" ;;
  esac
done < <(requirements "$rev")

shipped=$(git diff --name-only "$tag" "$rev" | grep -vE "$NOT_SHIPPED" | grep -vx VERSION || true)
if [ -n "$shipped" ]; then bump 1 "$(echo "$shipped" | wc -l | tr -d ' ') shipped file(s) changed"; fi

names=(none patch minor major)
echo "${names[$level]}"
for r in ${reasons[@]+"${reasons[@]}"}; do echo "$r"; done
