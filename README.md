<h1 align="center">Template Project</h1>

<p align="center">A spec-first project, built with Claude Code.</p>

> [!WARNING]
> **Certified, artisanal, vibe-coded slop.**
>
> No human has read this code. An AI wrote all of it while a person said "yeah, looks
> good" and pressed Enter a lot.

<!-- template:begin -->
## Using this template

A stack-neutral starting point for building software with
[Claude Code](https://claude.com/claude-code), spec first. It is the workflow from
[gtk-desktop-template](https://github.com/DisposableSoftware/gtk-desktop-template) with the
GTK, Rust and Nix taken out: the spec, the skills that drive it, the subagents that do the
reading, and the scripts that keep the spec and the code in step. Bring your own language
and toolchain.

You need git, bash, awk, perl and the [GitHub CLI](https://cli.github.com). Everything
works on macOS and Linux.

1. Create your repo from this one: **Use this template** on GitHub, or

   ```sh
   gh repo create my-project --public --template DisposableSoftware/spec-workflow
   ```

   and clone it. With one worktree per branch:

   ```sh
   git clone --bare https://github.com/you/my-project.git my-project/.bare
   cd my-project && echo "gitdir: ./.bare" > .git
   git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
   git fetch origin && git worktree add main main && cd main
   ```

2. Name it:

   ```sh
   scripts/init.sh "My Project"
   scripts/check.sh
   git commit -am "Name the template My Project"
   ```

   The script removes itself and this section, and enables the pre-push hook.

3. Set up the stack. Add your build, lint and test commands to `scripts/check.sh` and the
   Commands section of `CLAUDE.md`, and the files your stack ignores to `.gitignore`.
4. Edit `spec/product.md` to say what the project is, its non-goals and its stack
   constraints. Then start Claude Code and ask for features with `/feature`, fixes with
   `/bug`, and planned work with `/implement`.

What you get:

- **`spec/`**: every behaviour as a numbered requirement with a status and how it is
  verified. `CLAUDE.md` makes every change go spec first: a `spec:` commit, then code
  with a `Spec: ID` trailer.
- **`/feature`, `/bug` and `/implement`** (`.claude/skills/`): `/feature` drafts the spec
  change and `/bug` reproduces a bug and drafts the spec gap; both ask you to approve
  and implement, or approve the spec only. `/implement` builds the roadmap's approved
  rows in order, one verified commit each.
- **Subagents** (`.claude/agents/`): `spec-researcher` does the read-only code survey and
  bug tracing, so file dumps stay out of the main conversation, and `spec-verifier`
  checks each change against its rows before it is committed, with fresh eyes.
- **One gate** (`scripts/check.sh`): the spec lint, the tooling tests and your project's
  checks. `spec-lint.sh` catches duplicate or misfiled IDs, unknown statuses, `done` rows
  with nothing verifying them, and a roadmap out of step with the spec.
- **Releases**: `release-check.sh` recommends a semver bump from the spec's status
  changes, `release.sh` bumps `VERSION`, tags and drafts notes, the pre-push hook offers
  to do it all when you push main, and `/release` does it from Claude Code.

<!-- template:end -->

## Development

What the project does is written down in [`spec/`](spec/README.md); see
[`CLAUDE.md`](CLAUDE.md) for how changes are made.

```sh
scripts/check.sh            # spec lint, tooling tests, project checks
scripts/release-check.sh    # what the next release would be, and why
```

## License

MIT, see [LICENSE](LICENSE).
