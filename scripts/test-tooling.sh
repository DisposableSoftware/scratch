#!/usr/bin/env bash
# Tests for the scripts in scripts/ and .githooks/, each in a throwaway git repo that holds a
# copy of this checkout's spec, scripts and docs. scripts/check.sh is stubbed in the copies, so
# the release tests don't recurse into these tests.
# Usage: scripts/test-tooling.sh [TEST...]   (runs every test by default)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-tooling.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Keep the user's git config (signing, hooks, default branch) out of the test repos.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

die() { echo "$*"; exit 1; }
commit() { git add -A && git commit -qm "$@"; }

new_repo() {
  local dir="$work/$T" p
  mkdir -p "$dir"
  for p in spec scripts .githooks CLAUDE.md README.md VERSION; do
    if [ -e "$root/$p" ]; then cp -R "$root/$p" "$dir/"; fi
  done
  cd "$dir"
  printf '#!/bin/sh\nexit 0\n' >scripts/check.sh
  git init -q -b main
  commit init
}

# A small spec: area A with a done row and a planned one, and a roadmap listing the planned one.
fixture() {
  rm -f spec/*.md
  cat >spec/README.md <<'EOF'
| File | Prefix | Covers |
|------|--------|--------|
| [a.md](a.md) | `A` | Area A |
| [roadmap.md](roadmap.md) | — | Order of work |
EOF
  cat >spec/a.md <<'EOF'
| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `A-1` | One. | done | t1 |
| `A-2` | Two. | planned | t2 |
EOF
  roadmap '1. `A-2`: two.'
  commit fixture
}
roadmap() { printf '# Roadmap\n\n%s\n\n## Verification backlog\n\n%s\n' "$1" "${2:-None.}" >spec/roadmap.md; }
row() { ID=$1 ROW=$2 perl -pi -e 's/^\| `\Q$ENV{ID}\E` \|.*$/$ENV{ROW}/' spec/a.md; }

expect_lint_error() {
  local out
  if out=$(scripts/spec-lint.sh 2>&1); then die "spec-lint passed; expected: $1"; fi
  echo "$out" | grep -qF -- "$1" || die "spec-lint output lacks '$1':"$'\n'"$out"
}
expect_level() {
  local out
  out=$(scripts/release-check.sh)
  [ "$(echo "$out" | head -1)" = "$1" ] || die "release-check said:"$'\n'"$out"$'\n'"expected $1"
  [ -z "${2:-}" ] || echo "$out" | grep -qF -- "$2" || die "release-check reasons lack '$2':"$'\n'"$out"
}
tagged() { echo 0.1.0 >VERSION && commit "0.1.0" && git tag v0.1.0; }

lint_passes_on_this_spec() { new_repo; scripts/spec-lint.sh; }
lint_passes_on_fixture() { new_repo; fixture; scripts/spec-lint.sh; }
lint_duplicate_id() { new_repo; fixture; echo '| `A-1` | Again. | done | t |' >>spec/a.md; expect_lint_error "A-1: the ID is used more than once"; }
lint_bad_status() { new_repo; fixture; row A-1 '| `A-1` | One. | finished | t1 |'; expect_lint_error "status 'finished'"; }
lint_unlisted_file() { new_repo; fixture; printf '| ID | R | Status |\n|-|-|-|\n| `B-1` | x | done |\n' >spec/b.md; expect_lint_error "spec/b.md:1: not listed"; }
lint_wrong_prefix() { new_repo; fixture; echo '| `B-1` | x | done | t |' >>spec/a.md; expect_lint_error "B-1: spec/a.md uses the prefix A"; }
lint_unverified_done() { new_repo; fixture; row A-1 '| `A-1` | One. | done |  |'; expect_lint_error "A-1: done, but Verified by is empty"; }
lint_status_with_note() { new_repo; fixture; row A-1 '| `A-1` | One. | done (ongoing) | t1 |'; roadmap '1. `A-2`.' '- `A-1`: recheck.'; scripts/spec-lint.sh; }
lint_roadmap_unknown_id() { new_repo; fixture; roadmap '1. `A-2`. 2. `A-9`.'; expect_lint_error "A-9: listed, but no spec row"; }
lint_roadmap_done_listed() { new_repo; fixture; roadmap '1. `A-1`. 2. `A-2`.'; expect_lint_error "A-1: listed, but it is done"; }
lint_roadmap_unlisted_planned() { new_repo; fixture; roadmap 'None.'; expect_lint_error "A-2: planned, but not listed"; }
lint_roadmap_unknown_backlog() { new_repo; fixture; roadmap '1. `A-2`.' '- `A-7`'; expect_lint_error "A-7: in the verification backlog"; }

release_check_no_tag() { new_repo; fixture; expect_level minor "no v* tag yet"; }
release_check_none() { new_repo; fixture; tagged; row A-2 '| `A-2` | Two, reworded. | planned | t2 |'; commit "spec: reword"; expect_level none; }
release_check_patch() { new_repo; fixture; tagged; mkdir src; echo x >src/x; commit "Add x"; expect_level patch "1 shipped file(s) changed"; }
release_check_minor() { new_repo; fixture; tagged; row A-2 '| `A-2` | Two. | done | t2 |'; roadmap None.; commit "Build A-2"; expect_level minor "A-2 is now done (was planned)"; }
release_check_major_breaking() { new_repo; fixture; tagged; git commit -q --allow-empty -m "Change x" -m "BREAKING: x is gone"; expect_level major "BREAKING"; }
release_check_major_dropped() { new_repo; fixture; tagged; row A-1 '| `A-1` | One. | dropped: unwanted | t1 |'; commit "spec: drop A-1"; expect_level major "A-1 is now dropped (was done)"; }

release_bumps_and_tags() {
  local name tag
  new_repo; fixture; tagged
  name=$(sed -n 's/^NAME="\(.*\)"$/\1/p' scripts/release.sh)
  row A-2 '| `A-2` | Two. | done | t2 |'; roadmap None.; commit "Build A-2"
  tag=$(scripts/release.sh minor "$work/notes")
  [ "$tag" = v0.2.0 ] || die "printed $tag"
  [ "$(cat VERSION)" = 0.2.0 ] || die "VERSION is $(cat VERSION)"
  [ "$(git log -1 --format=%s)" = "$name 0.2.0" ] || die "commit is $(git log -1 --format=%s)"
  git rev-parse -q --verify refs/tags/v0.2.0 >/dev/null || die "no tag"
  [ -z "$(git status --porcelain)" ] || die "tree is dirty"
  grep -qF '`A-2`: Two.' "$work/notes" || die "notes lack A-2: $(cat "$work/notes")"
  grep -qF -- '- Build A-2' "$work/notes" || die "notes lack the commit: $(cat "$work/notes")"
  if git remote | grep -q .; then die "a remote appeared"; fi
}
release_keeps_version_on_failure() {
  new_repo; fixture; tagged
  printf '#!/bin/sh\nexit 1\n' >scripts/check.sh; commit "Failing checks"
  if scripts/release.sh patch "$work/notes" 2>/dev/null; then die "release.sh succeeded"; fi
  [ "$(cat VERSION)" = 0.1.0 ] || die "VERSION is $(cat VERSION)"
  if git rev-parse -q --verify refs/tags/v0.1.1 >/dev/null; then die "tagged anyway"; fi
  [ -z "$(git status --porcelain)" ] || die "tree is dirty"
}

prepush_skips() {
  local out
  new_repo; fixture
  out=$(echo "refs/heads/main 1 refs/heads/main 0" | NO_RELEASE_CHECK=1 .githooks/pre-push 2>&1) || die "NO_RELEASE_CHECK push failed"
  [ -z "$out" ] || die "NO_RELEASE_CHECK printed: $out"
  out=$(echo "refs/heads/x 1 refs/heads/x 0" | .githooks/pre-push 2>&1) || die "branch push failed"
  [ -z "$out" ] || die "branch push printed: $out"
}

init_renames() {
  local template="Template"" Project"
  new_repo
  if [ ! -e scripts/init.sh ]; then echo "skip: scripts/init.sh was already run"; return 0; fi
  scripts/init.sh "Zed Thing" >/dev/null
  if git grep -qF "$template"; then die "still named: $(git grep -nF "$template")"; fi
  git grep -qF "Zed Thing" -- CLAUDE.md spec/README.md scripts/release.sh || die "new name missing"
  if grep -q 'template:begin' README.md; then die "README keeps the template sections"; fi
  [ ! -e scripts/init.sh ] || die "init.sh is still there"
  if grep -q 'scripts/init.sh' CLAUDE.md; then die "CLAUDE.md still lists init.sh"; fi
  grep -qF '| `TOOL-9` |' spec/tooling.md && grep -F '| `TOOL-9` |' spec/tooling.md | grep -q '| dropped' || die "TOOL-9 not dropped"
  [ "$(git config core.hooksPath)" = .githooks ] || die "hooks not enabled"
  scripts/spec-lint.sh
}

if [ $# -gt 0 ]; then tests=("$@"); else
  tests=()
  while read -r _ _ f; do
    case $f in lint_* | release_* | prepush_* | init_*) tests+=("$f") ;; esac
  done < <(declare -F)
fi

failed=0
for T in "${tests[@]}"; do
  set +e
  (set -e; "$T") >"$work/$T.log" 2>&1
  rc=$?
  set -e
  if [ $rc = 0 ]; then echo "ok   $T"; else
    echo "FAIL $T"; sed 's/^/     /' "$work/$T.log"; failed=$((failed + 1))
  fi
done
[ "$failed" = 0 ] || { echo "$failed of ${#tests[@]} tooling test(s) failed" >&2; exit 1; }
