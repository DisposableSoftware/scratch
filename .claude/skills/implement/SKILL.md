---
name: implement
description: Work through the outstanding items in Template Project's spec/roadmap.md, the verification backlog first and then the planned requirements in roadmap order, implementing and verifying each one against the spec and committing it. Use when the user runs /implement.
argument-hint: [IDs to limit the run to, e.g. AREA-3 AREA-7]
disable-model-invocation: true
---

# /implement — build what the roadmap says is next

Limit: $ARGUMENTS

Follow the spec-first workflow in `CLAUDE.md`. The spec rows are already agreed: they were approved through `/feature` or `/bug`, so there is no approval gate here. `/feature` and `/bug` also hand over to this skill, with the IDs they just approved as the limit. This skill does steps 2–4 of the workflow for each outstanding item, one item at a time, in the order `spec/roadmap.md` gives.

## 1. Collect the work

1. Read `spec/README.md` and `spec/roadmap.md`, then search all of `spec/` for rows with status `planned` or `partial`.
2. The work list, in order:
   1. **The verification backlog** in `roadmap.md`. The roadmap says to clear it before new planned work.
   2. **The requirements the roadmap lists**, in its order: `planned` rows, and `partial` rows that `/bug` left with the bug written in as the gap.
3. If the limit above names IDs, keep only those items, still in roadmap order.
4. Check the roadmap against the spec (`scripts/spec-lint.sh` reports the first two):
   - A `planned` row that the roadmap doesn't list: add it to the end of the roadmap's list, and say so in the report.
   - A roadmap entry whose row is already `done` or `dropped`: remove it from the roadmap.
   - A `partial` row with a gap that code can close, but no roadmap entry: list it at the end of the work list, and ask before working on it (it may be a gap the user accepted).
5. If the list is empty, say "Nothing is outstanding" and stop.
6. Tell the user the list (ID, one line each, and how each will be verified) before starting. Don't wait for an answer unless something in step 2 below needs one.

## 2. Check each item before building it

Re-read the row, its neighbours, the implementation notes and the non-goals in `spec/product.md`. Stop and ask with `AskUserQuestion` (quote the rows by ID and text, give concrete options, recommended first) when:

- **The row can't be built as written:** it is ambiguous, it can't be checked, or the stack can't do it.
- **It conflicts** with another requirement, a non-goal or a stack constraint, including one that changed after the row was written.
- **It needs a new dependency.** `CLAUDE.md` says to ask first.
- **It needs a decision only the user can make**, such as a choice of default or wording that the spec leaves open.

If the answer changes the spec, commit the spec change on its own (`spec: <summary>`) before the code, as `/feature` does. If the user puts the item off, leave it `planned` and move on to the next one.

For an item that touches many files, have the `spec-researcher` subagent map the code first, or the `Plan` subagent draft the change, before you write code.

## 3. Build each item

For each item in turn:

1. **Code.** Implement only what the row says. If the code needs behaviour the spec doesn't describe, go back to step 2 for it. Keep the change small and match the surrounding code.
2. **Verify** (`CLAUDE.md` step 3):
   - `scripts/check.sh` passes.
   - Check the row as its **Verified by** column says. Prefer adding an automated test where one is possible.
   - For manual checks, follow "Manual testing" in `CLAUDE.md`, keep screenshots or output of visible changes for the report, and ask the user before a check that takes over their screen or input. If the check can't run, mark the row `partial` and say why.
   - Re-run the manual scripts for the area, since a change often moves something they rely on.
   - Ask the `spec-verifier` subagent to check the uncommitted change against the row: give it the ID and say the change is in `git diff`. Read what it reports, confirm each point yourself, and fix real gaps before going on. A gap you can't close in this item makes the row `partial`.
   - A row from `/bug` names its regression check in **Verified by**. Run it before the fix and confirm it still fails, then after the fix and confirm it passes. Remove its expected-failure marker.
3. **Update the spec.** Set the row to `done`, or `partial` with the gap written in, and fill in **Verified by**. Remove the item from `roadmap.md`, or move a `partial` gap to its verification backlog. Run `scripts/spec-lint.sh`.
4. **Commit** the code and the status update with a `Spec: ID` trailer listing the requirements it implements or affects. One commit per item, so a later item that fails doesn't hold back the earlier ones.

A verification backlog item usually needs no code: run the check, then update the row and the backlog. If the check fails, the item is a bug: leave the backlog entry, set the row to `partial` with what failed, and suggest `/bug` in the report. Don't fix it here, because the spec change for a bug needs the user's approval.

If an item can't be finished (a check fails and the fix isn't clear, or the user isn't available to answer step 2), leave its row as it was, revert its uncommitted changes, note why, and go on to the next item that doesn't depend on it.

## 4. Report

When the list is done:

- **Done:** each ID and how it was verified, with screenshots or output of visible changes.
- **Left over:** each ID that is still `planned` or `partial`, and why (a question for the user, a failed check, a check that needs the user's session).
- **Roadmap changes:** entries you added, removed or reordered.
- Problems you or `spec-verifier` noticed that no row covers. Don't fix those: suggest `/feature` or `/bug`.

Don't push or release. Say whether `scripts/release-check.sh` now recommends a release.
