# Template Project: specification

This folder is the source of truth for what Template Project does. The code implements the spec. If the code and the spec disagree, the code is wrong, or the spec must be changed first.

## Files

| File | Prefix | Covers |
|------|--------|--------|
| [product.md](product.md) | `PROD` | Goals, non-goals, platform and stack constraints |
| [tooling.md](tooling.md) | `TOOL` | The workflow's own scripts: spec lint, checks, releases |
| [roadmap.md](roadmap.md) | — | The order of planned work, which `/implement` follows |

Add a file with a new prefix when a feature area doesn't fit these, and list it here. `scripts/spec-lint.sh` reads this table: every spec file must be listed, and its IDs must use its prefix.

## Requirement format

Each requirement is one line in a table:

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `AREA-1` | One sentence that can be checked. | done | the test's name, or `manual:` and what to check |

- **IDs are permanent.** Do not renumber them or reuse one. When a requirement is dropped, keep its row, set the status to `dropped`, and give the reason.
- **Status** is one of:
  - `planned`: agreed but not built.
  - `partial`: built, but with a known gap. The gap is written in the row (`partial: <gap>`).
  - `done`: built and verified.
  - `dropped`: no longer wanted.
- Write behaviour, not implementation. Keep the "how" short, and put it under **Implementation notes** when it is not obvious or a past attempt failed.
- **Verified by** names the test, or says `manual:` with what to check. A `done` row must fill it in. Tables of standing constraints (like `product.md`) may leave the column out.

`scripts/release-check.sh` reads the status column: a requirement that became `done` or `partial` since the last release means a minor bump, and a shipped one that became `dropped` means a major one. `/release` pushes `main` and acts on that recommendation.
