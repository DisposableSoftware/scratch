# Template Project

_One line on what Template Project is. Say it properly in [`spec/product.md`](spec/product.md)._

**What the project does is defined in [`spec/`](spec/README.md).** This file covers how to work on it.

## Spec-first workflow (mandatory)

Every change follows these steps, in order. Three skills run them. `/feature` (`.claude/skills/feature/`) turns a request into spec rows, and `/bug` (`.claude/skills/bug/`) reproduces a bug and finds the spec gap that let it happen. Both end by asking the user to **approve and implement** or **approve the spec only**, and neither writes code itself. `/implement` (`.claude/skills/implement/`) builds what is approved: it works through `spec/roadmap.md`, the verification backlog first and then the listed rows in order, with one commit per requirement.

1. **Spec.** Before touching code, update the relevant `spec/*.md`.
   - **New behaviour or a changed requirement:** add or edit a requirement row. A new row gets the next free ID in its prefix, with status `planned`. If the request is unclear, settle the wording with the user before coding.
   - **Bug fix:** find the requirement the bug breaks. If no requirement covers the behaviour, the bug is a gap in the spec, so add one.
   - **Refactor with no behaviour change:** no spec edit, but it must still pass step 3.
   - Commit the spec change on its own, before the code: `spec: <summary>`.
2. **Code.** Implement only what the spec says. If the code needs behaviour the spec doesn't describe, go back to step 1.
3. **Confirm against the spec.** Before the code commit:
   - Run `scripts/check.sh`. It runs `scripts/spec-lint.sh` (spec format and roadmap consistency), the tooling tests, and the project's own build, lint and test commands.
   - For every requirement ID touched, verify it as its **Verified by** column says (an automated test, or a manual check). Prefer adding an automated test where one is possible.
   - Have the `spec-verifier` subagent re-read the change against the requirement text and look for behaviour the spec doesn't mention (see [Subagents](#subagents)).
   - Update the row: set the status to `done` (or `partial` with the gap written in), and fill in **Verified by**. Update `roadmap.md` if a planned item landed.
4. **Commit** the code with a `Spec: ID, ID` trailer listing the requirements it implements or affects, and tell the user which IDs were verified and how.

When reporting to the user, say plainly if something could only be partly verified (e.g. the check needs the user's session and they were using it, so the manual test was skipped).

## Commands

```sh
scripts/check.sh                      # the gate before every code commit and release
scripts/spec-lint.sh                  # spec format and roadmap consistency only
scripts/test-tooling.sh               # tests for the scripts in scripts/
scripts/release-check.sh              # recommended version bump since the last v* tag
git config core.hooksPath .githooks   # once per clone: enables the pre-push release check
```

<!-- Add the project's build, run, lint and test commands here, including how to run a
     single test, and add the checks to scripts/check.sh so the workflow runs them. -->

## Subagents

Keep the main conversation for the spec, decisions and edits. Hand research that means reading many files to a subagent, and run independent questions in parallel.

| Agent | Use it for | Tools |
|-------|------------|-------|
| `spec-researcher` (`.claude/agents/`) | Where a behaviour lives now (`/feature` step 1), tracing a bug to its cause and finding the same mistake elsewhere (`/bug` step 3), mapping code to spec IDs | Read-only |
| `spec-verifier` (`.claude/agents/`) | Checking a change against the rows it claims before each commit (`/implement` step 3) | Read-only, plus git through Bash |
| `Plan` (built in) | An item that touches many files, before writing code | Read-only |

- Brief each agent with the spec IDs, the question, and the worktree or paths to search. Ask for conclusions with `file:line` references, not file contents.
- Treat findings as leads. Read the cited lines yourself before editing or reporting them as fact.

## Code layout

Keep this table current: one line per module, with the spec IDs it implements.

```
scripts/check.sh          the single gate: spec lint, tooling tests, project checks     TOOL-10
scripts/spec-lint.sh      spec format and roadmap consistency                            TOOL-1…5
scripts/lib/spec-rows.awk parses requirement rows (shared by lint and release check)
scripts/test-tooling.sh   tests for the scripts, in throwaway git repos
scripts/release-check.sh  recommended version bump since the last v* tag (spec delta)  TOOL-6
scripts/release.sh        bump VERSION, commit "Template Project X.Y.Z", tag, notes      TOOL-7
scripts/init.sh           names a project made from the template, then removes itself  TOOL-9
scripts/manual/           manual checks, one script per area, each naming its IDs
.githooks/pre-push        on a push of main, offers to release                         TOOL-8
.claude/skills/           /feature, /bug, /implement, /release
.claude/agents/           spec-researcher, spec-verifier
spec/                     the specification
```

## Conventions

- Keep the dependency list short. Ask before adding a dependency.
- Look up the docs or read the source of a library before guessing at its API.
- Comments only when the reason is not obvious.
- Scripts in `scripts/` run on macOS (bash 3.2, BSD tools) as well as Linux: no `mapfile`, no `sed -i`, no GNU-only flags.
- Commits: `spec: <summary>` for spec changes, a `Spec: ID, ID` trailer on code commits, `BREAKING` in the body for incompatible changes (`scripts/release-check.sh` reads all three). No Claude-Session links in commit messages.

## Releasing

The version lives in `VERSION`. If the stack keeps it somewhere else too (`package.json`, `Cargo.toml`, `pyproject.toml`), extend `set_version` in `scripts/release.sh`.

`scripts/release-check.sh` recommends a bump from the commits since the last `v*` tag: major for `BREAKING` or a shipped requirement that became `dropped`, minor when a requirement became `done` or `partial`, patch for other changes outside `spec/`, docs and tooling. `scripts/release.sh LEVEL NOTES` bumps `VERSION`, runs `scripts/check.sh`, commits and tags, and drafts notes; then `git push origin main vX.Y.Z` and `gh release create vX.Y.Z -F NOTES`. With the hook enabled, pushing main offers all of this (`NO_RELEASE_CHECK=1` skips it). `/release` (`.claude/skills/release/`) runs all of this: it pushes main, releases a patch or minor bump without asking, and asks first for a major one. Otherwise ask before pushing.

## Manual testing

Prefer adding a script to `scripts/manual/` over ad-hoc commands. Each script names the spec IDs it checks.

<!-- Describe how to run checks without touching the user's own session or data: temp
     config, state and cache dirs, a headless display, a scratch database, a test account.
     Say which checks need the user's real environment, and the guards to run first. -->
