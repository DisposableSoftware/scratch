#!/usr/bin/env bash
# Checks spec/ for the mistakes the workflow can't afford: duplicate or misfiled IDs, unknown
# statuses, done rows with nothing verifying them, and a roadmap out of step with the spec.
# Prints each problem as file:line: message, and exits 1 if there are any.
# Usage: scripts/spec-lint.sh
set -euo pipefail
cd "$(dirname "$0")/.."

problems=0
fail() { echo "$1" >&2; problems=$((problems + 1)); }

files=()
for f in spec/*.md; do
  case $f in spec/README.md | spec/roadmap.md) ;; *) files+=("$f") ;; esac
done
[ ${#files[@]} -gt 0 ] || { echo "spec-lint: no spec files" >&2; exit 1; }
rows=$(awk -f scripts/lib/spec-rows.awk "${files[@]}")

# "file prefix" for each row of the Files table in spec/README.md.
prefixes=$(awk -F'|' '$2 ~ /\]\([a-z0-9_-]+\.md\)/ && $3 ~ /`[A-Z]+`/ {
  f = $2; sub(/.*\]\(/, "", f); sub(/\).*/, "", f); p = $3; gsub(/[ `]/, "", p); print f, p }' spec/README.md)

for f in "${files[@]}"; do
  echo "$prefixes" | grep -q "^${f#spec/} " || fail "$f:1: not listed in the Files table in spec/README.md"
done

while read -r id; do
  [ -n "$id" ] || continue
  fail "$(echo "$rows" | awk -F'\t' -v i="$id" '$1 == i { printf "%s%s", sep, $4; sep = ", " }'): $id: the ID is used more than once"
done < <(echo "$rows" | cut -f1 | sort | uniq -d)

while IFS=$'\t' read -r id st cols loc vb; do
  [ -n "$id" ] || continue
  case $st in planned | partial | done | dropped) ;; *)
    fail "$loc: $id: status '$st' is not one of planned, partial, done, dropped" ;;
  esac
  file=${loc%%:*}
  want=$(echo "$prefixes" | awk -v f="${file#spec/}" '$1 == f { print $2 }')
  if [ -n "$want" ] && [ "${id%-*}" != "$want" ]; then
    fail "$loc: $id: $file uses the prefix $want"
  fi
  if [ "$st" = done ] && [ "$cols" -ge 4 ] && [ -z "$vb" ]; then
    fail "$loc: $id: done, but Verified by is empty"
  fi
done <<<"$rows"

status_of() { echo "$rows" | awk -F'\t' -v i="$1" '$1 == i { print $2; exit }'; }
listed=$(awk '/^## Verification backlog/ { exit } { print }' spec/roadmap.md | grep -oE '`[A-Z]+-[0-9]+`' | tr -d '`' | sort -u || true)
backlog=$(awk '/^## Verification backlog/ { on = 1; next } on' spec/roadmap.md | grep -oE '`[A-Z]+-[0-9]+`' | tr -d '`' | sort -u || true)

for id in $listed; do
  case $(status_of "$id") in
    planned | partial) ;;
    "") fail "spec/roadmap.md: $id: listed, but no spec row has this ID" ;;
    *) fail "spec/roadmap.md: $id: listed, but it is $(status_of "$id"); remove it from the roadmap" ;;
  esac
done
for id in $backlog; do
  [ -n "$(status_of "$id")" ] || fail "spec/roadmap.md: $id: in the verification backlog, but no spec row has this ID"
done
while IFS=$'\t' read -r id st _ loc _; do
  [ "$st" = planned ] || continue
  echo "$listed" | grep -qx "$id" || fail "$loc: $id: planned, but not listed in spec/roadmap.md"
done <<<"$rows"

[ "$problems" = 0 ] || { echo "spec-lint: $problems problem(s)" >&2; exit 1; }
