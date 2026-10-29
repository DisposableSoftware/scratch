# Scratch

An iPhone player for a Navidrome server, over the OpenSubsonic API. SwiftUI, iOS 27, one app target, no dependencies.

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
scripts/arch-lint.sh                  # the architecture rules in spec/architecture.md
scripts/test-arch-lint.sh             # tests for arch-lint, one break of each rule
```

`scripts/check.sh` builds the app and runs `ScratchTests` on the iPhone 17 simulator (iOS 27.0). Set `SCRATCH_SIMULATOR` to use another device. Directly:

```sh
xcodebuild -project Scratch.xcodeproj -scheme Scratch \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
# one suite or one test:
  -only-testing:ScratchTests/AppContainerTests
  -only-testing:ScratchTests/AppContainerTests/buildKeepsTheCoordinatorItWasGiven
```

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). The iOS 27 simulator runtime has to be installed (Xcode ▸ Settings ▸ Components); after an Xcode update it may need downloading again.

## Architecture

Scratch follows `~/Notes/Tech Notes/Work Notes/Architecture Design.md` **strictly**. Read the note before adding a type. [`spec/architecture.md`](spec/architecture.md) says how it maps onto one app target, and `scripts/arch-lint.sh` fails the build on the rules a script can see. Its rule names (`[no_upward_refs]` and so on) are in the Verified by column there.

| Folder | Holds | May use |
|--------|-------|---------|
| `App/` | The host: `@main`, `AppCoordinator` and its destination handlers, `RootView`, Port adapters | Everything |
| `Container/` | `AppContainer` and `build(…)`, the `Has*` protocols | Everything except `App/` types |
| `UI/` | Views, ViewModels, `…Action` and `…Route` enums; the navigation mechanism: `Coordinator`, `NavigationDestination`, the view factory, RoutingUseCases | UseCase protocols, `Routing/`, `Models/`, `State/`, the `Has*` protocols |
| `Routing/` | `…Step` enums and Routers: pure functions, no navigation | `Models/`, `State/` |
| `UseCases/` | UseCase protocols and `Default…` implementations | Gateway protocols, `Models/`, `State/` |
| `State/` | Shared `ObservableObject`s the UseCases update | `Models/` |
| `Gateways/` | Gateway protocols and implementations: HTTP, Keychain, `UserDefaults`, AVFoundation | `Models/` |
| `Models/` | Domain values and the errors that cross layers | Nothing |

- Only `UI/` and `App/` import SwiftUI or UIKit.
- A concrete Gateway or UseCase is named only in its own folder and `Container/`. Everything else holds the protocol.
- Views read published state and call `viewModel.submitAction(_:)`, or `viewModel.binding(_:to:)` for controls. Nothing else.
- New dependencies for a ViewModel: add a `Has…` protocol in `Container/HasUseCases.swift`, add it to `AllUseCases`, and build the implementation in `AppContainer.build(…)`.
- The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: everything is main-actor unless marked `nonisolated`. Keep blocking work out of it. Value models used in `@Test(arguments:)` must be `nonisolated`, since Swift Testing evaluates arguments off the main actor.

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
Scratch.xcodeproj         one app target, one test target, synchronized folders: new files join automatically
Scratch/App/              host: ScratchApp, AppCoordinator + RootPresenter, RootView      ARCH-13, ARCH-15
Scratch/Container/        AppContainer, Has* protocols                                   ARCH-9, ARCH-14
Scratch/Routing/          AppStep + AppFlowData, AppRouter (pure)                       ARCH-11, SRV-1
Scratch/UI/               ViewModel, Coordinator + NavigationDestination, NavigationRoute + RoutingViewModel   ARCH-8, ARCH-10, ARCH-12, ARCH-13
Scratch/UI/               AppRoutingUseCase + ViewFactory, AppViewFactory, SetupView(Model), LibraryView     ARCH-11, SRV-1, SRV-3
Scratch/State/            SessionState (the signed-in ServerAccount)                    SRV-1
Scratch/Models/           ServerAddress (URL parsing), SubsonicCredentials (salt+token)  SRV-2, SRV-4
Scratch/Gateways/         SubsonicRequest: every server URL, signed                      PROD-3, SRV-4
Scratch/Gateways/         NetworkSession (+ same-origin redirects), SubsonicClient (envelope → ServerError)  SRV-3
Scratch/Gateways/         RemoteServerGateway (ping), KeychainCredentialGateway          SRV-3, SRV-5
Scratch/UseCases/         ConnectUseCase, SessionUseCase (restore, rejection, sign out) SRV-3, SRV-5, SRV-6, SRV-7
Scratch/Models/           AppEnvironment (.live storage), ServerError/ConnectError/StorageError
Scratch/Models/           Track                                                          LIB-1
Scratch/State/            LibraryState (tracks loaded so far)                           LIB-2
Scratch/Gateways/         RemoteLibraryGateway (search3), RemoteCoverArtGateway (getCoverArt + NSCache)  LIB-2, LIB-5
Scratch/UseCases/         LibraryUseCase (paging), CoverArtUseCase                       LIB-2, LIB-5
Scratch/UI/               LibraryView(Model): rows, phases, prefetch, art, tap to play   LIB-1…5, PLAY-1
Scratch/Models/           PlaybackStatus, AudioPlayerEvent
Scratch/State/            PlaybackState (queue, current index, status, time)            PLAY-1
Scratch/Gateways/         AVPlayerAudioGateway (stream URL, AVPlayer + audio session → events)   PLAY-1, PLAY-6, PLAY-7, PLAY-8
Scratch/Gateways/         MPNowPlayingGateway (lock screen info, remote commands)        PLAY-6
Scratch/Info.plist        background audio (PLAY-6), arbitrary loads for plain-http servers (SRV-2)
Scratch/UseCases/         PlaybackUseCase (queue, end, failure, interruption, lock screen rules)   PLAY-1, PLAY-4…8
Scratch/Models/           StreamQuality, TranscodingSettings, NetworkKind               TRANS-1…3
Scratch/Gateways/         UserDefaultsSettingsGateway, PathMonitorNetworkGateway, SubsonicRequest.stream   TRANS-3…5
Scratch/UseCases/         TranscodingUseCase (settings, quality for the next track)     TRANS-1…5
Scratch/UI/               SettingsView(Model): server and sign out, transcoding per network   LIB-6, SRV-7, TRANS-1, TRANS-2
Scratch/UI/               PlayerViewModel (mirrors PlaybackState), NowPlayingBar, PlayerView   PLAY-2, PLAY-3, PLAY-8, TRANS-6
ScratchTests/SnapshotTests  skipped unless snapshots.sh passes a directory in
scripts/manual/snapshots.sh  renders the bar and player (playing, failed) to PNGs
scripts/manual/live-connect.sh  SRV-3/SRV-5 against a real server; credentials from the environment only
Scratch/Info.plist        background audio, arbitrary loads (merged with generated keys)
ScratchTests/             Swift Testing suites; Support/ holds mocks, StubURLProtocol, TestContainer   ARCH-16
ScratchTests/LiveServerTests  skipped unless live-connect.sh passes a server in
scripts/arch-lint.sh      the architecture rules a script can check, app and tests      ARCH-1…10, 12–16
scripts/test-arch-lint.sh tests for arch-lint
scripts/check.sh          the single gate: spec lint, tooling tests, project checks     TOOL-10
scripts/spec-lint.sh      spec format and roadmap consistency                            TOOL-1…5
scripts/lib/spec-rows.awk parses requirement rows (shared by lint and release check)
scripts/test-tooling.sh   tests for the scripts, in throwaway git repos
scripts/release-check.sh  recommended version bump since the last v* tag (spec delta)  TOOL-6
scripts/release.sh        bump VERSION + MARKETING_VERSION, commit, tag, notes           TOOL-7
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

The version lives in `VERSION`, and `scripts/release.sh` copies it to `MARKETING_VERSION` in `Scratch.xcodeproj`. Don't edit either by hand.

`scripts/release-check.sh` recommends a bump from the commits since the last `v*` tag: major for `BREAKING` or a shipped requirement that became `dropped`, minor when a requirement became `done` or `partial`, patch for other changes outside `spec/`, docs and tooling. `scripts/release.sh LEVEL NOTES` bumps `VERSION`, runs `scripts/check.sh`, commits and tags, and drafts notes; then `git push origin main vX.Y.Z` and `gh release create vX.Y.Z -F NOTES`. With the hook enabled, pushing main offers all of this (`NO_RELEASE_CHECK=1` skips it). `/release` (`.claude/skills/release/`) runs all of this: it pushes main, releases a patch or minor bump without asking, and asks first for a major one. Otherwise ask before pushing.

## Manual testing

Prefer adding a script to `scripts/manual/` over ad-hoc commands. Each script names the spec IDs it checks.

- Use the simulator, never the user's phone: `xcrun simctl boot "iPhone 17"`, build with `-derivedDataPath build/`, then `xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Scratch.app` and `xcrun simctl launch booted lol.weston.scratch`. Screenshots: `xcrun simctl io booted screenshot <file>`.
- Against a server, use the user's test server: ask for its address and credentials, and pass them at run time (environment variables), never in a script, a spec row or a commit. Navidrome's public demo (`https://demo.navidrome.org`, `demo` / `demo`) is the fallback.
- `xcrun simctl erase "iPhone 17"` resets the Keychain and `UserDefaults` for a first-launch check.
