# Product

Scratch is a small iOS player for a [Navidrome](https://www.navidrome.org) server. It connects to the user's own server, lists its tracks, and streams them, with control over how the server transcodes them. It is for one person and one server, and stays small.

## Requirements

| ID | Requirement | Status |
|----|-------------|--------|
| `PROD-1` | Every change follows the spec-first workflow in `CLAUDE.md`. | done (ongoing constraint) |
| `PROD-2` | Runs on iPhone with iOS 27 or later. | done (`IPHONEOS_DEPLOYMENT_TARGET = 27.0`, `TARGETED_DEVICE_FAMILY = 1`, not offered on Mac or Vision Pro) |
| `PROD-3` | Talks to the server only through the [OpenSubsonic API](https://opensubsonic.netlify.app) (Subsonic API 1.16.1 plus OpenSubsonic extensions), so any OpenSubsonic server works, with Navidrome as the reference. | done (ongoing constraint: every server URL is built by `SubsonicRequest`) |
| `PROD-4` | Follows the Container / UseCase / Router / Gateway architecture strictly (see [architecture.md](architecture.md)). | done (ongoing constraint, enforced by `scripts/arch-lint.sh`) |

## Non-goals

- Offline downloads and caching beyond what the system does for streams.
- More than one server at a time.
- Editing the library: playlists, ratings, stars, tags.
- Scrobbling, lyrics, radio, podcasts, video.
- CarPlay, iPad layouts, watchOS, macOS.
- Navidrome's native (web UI) API. It is undocumented and changes between releases.

## Stack constraints

- Swift 6 language mode with strict concurrency, SwiftUI, AVFoundation, MediaPlayer. Toolchain: Xcode 27.1, Swift 6.4.
- One app target and one unit-test target in a checked-in `Scratch.xcodeproj`. No Swift packages, local or remote, and no third-party dependencies.
- Ask before adding any dependency or target.
