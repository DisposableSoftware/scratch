# Tooling

The scripts that keep the spec and the code honest. They depend only on bash 3.2, git, awk, grep and perl, so they work in any project on macOS or Linux.

## Spec lint

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `TOOL-1` | `scripts/spec-lint.sh` fails when two requirement rows share an ID. | done | `test-tooling.sh: lint_duplicate_id` |
| `TOOL-2` | `scripts/spec-lint.sh` fails when a row's status is not `planned`, `partial`, `done` or `dropped`. | done | `test-tooling.sh: lint_bad_status` |
| `TOOL-3` | `scripts/spec-lint.sh` fails when a spec file is missing from the table in `spec/README.md`, or a row's ID doesn't use its file's prefix. | done | `test-tooling.sh: lint_unlisted_file`, `lint_wrong_prefix` |
| `TOOL-4` | `scripts/spec-lint.sh` fails when a `done` row in a table with a **Verified by** column leaves it empty. | done | `test-tooling.sh: lint_unverified_done` |
| `TOOL-5` | `scripts/spec-lint.sh` fails when the roadmap lists an ID that doesn't exist or isn't `planned` or `partial`, or a `planned` row isn't in the roadmap. | done | `test-tooling.sh: lint_roadmap_*` |

## Checks and releases

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `TOOL-6` | `scripts/release-check.sh` prints `major` for a `BREAKING` commit or a `done`/`partial` row that became `dropped`, `minor` when a row became `done` or `partial`, `patch` for other changes outside `spec/`, docs and tooling, and `none` otherwise, followed by the reasons. | done | `test-tooling.sh: release_check_*` |
| `TOOL-7` | `scripts/release.sh LEVEL NOTES` bumps `VERSION`, runs `scripts/check.sh`, commits `Scratch X.Y.Z`, tags `vX.Y.Z` and writes draft notes. It never pushes, and leaves the version unchanged when the checks fail. | done | `test-tooling.sh: release_bumps_and_tags`, `release_keeps_version_on_failure` |
| `TOOL-8` | On a push of `main`, `.githooks/pre-push` shows the recommended bump and offers to release; `NO_RELEASE_CHECK=1` or a push without a terminal skips it. | partial: the interactive release prompt has not been run since the port from gtk-desktop-template | `test-tooling.sh: prepush_skips`; `manual:` a push with no controlling terminal prints the bump and pushes without a release; push main from a terminal after a `done` row and check the prompt |
| `TOOL-9` | `scripts/init.sh NAME` replaces the template's name in every tracked file, removes the template-only README sections and drops this row, and deletes itself. | dropped: the project was initialised and the script removed | `test-tooling.sh: init_renames` |
| `TOOL-10` | `scripts/check.sh` is the one gate: it runs the spec lint, the tooling tests and the project's checks, and fails if any of them fails. | done | `manual:` break a spec row and check `scripts/check.sh` exits non-zero |
