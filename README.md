<p align="center"><img src="Scratch/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" alt="Scratch app icon"></p>

<h1 align="center">Scratch</h1>

<p align="center">A Navidrome player for iOS. Junk, but it plays your music.</p>

> [!WARNING]
> **Certified, artisanal, vibe-coded slop.**
>
> No human has read this code. An AI wrote all of it while a person said "yeah, looks
> good" and pressed Enter a lot.

## What it does

Scratch connects to your own [Navidrome](https://www.navidrome.org) server and plays what's
on it. One person, one server, and it stays small.

> [!NOTE]
> **Under development.** Features come and go, and things will change or break without
> warning. What the app does today is written down in [`spec/`](spec/README.md).

It talks to the server only through the [OpenSubsonic API](https://opensubsonic.netlify.app),
so other servers may work too. Navidrome is the one it's tested against.

## Running it

You need Xcode 27.1 and an iPhone simulator or device on iOS 27. There are no packages and
no dependencies.

```sh
open Scratch.xcodeproj
```

Pick the **Scratch** scheme, run it, and enter your server's address, username and
password.

## Development

What the app does is written down in [`spec/`](spec/README.md), every behaviour as a
numbered requirement with how it's checked. See [`CLAUDE.md`](CLAUDE.md) for how changes
are made: spec first, then code, with the architecture rules enforced by a lint.

```sh
scripts/check.sh            # spec lint, tooling tests, architecture lint, build, unit tests
scripts/release-check.sh    # what the next release would be, and why
```

The unit tests run on the iPhone 17 simulator. `scripts/manual/live-connect.sh` checks
against a real server; it reads the address and login from environment variables, never
from files.

## Credits

The colours are [Catppuccin](https://catppuccin.com), a community-driven pastel theme. The
palette is by the [Catppuccin organisation](https://github.com/catppuccin/catppuccin) and its
contributors, and is not ours; we only use it. The values are in
[`design/catppuccin/`](design/catppuccin), with a link back to the
[official palette](https://catppuccin.com/palette). Catppuccin is MIT-licensed. How the app
looks follows the DisposableSoftware [style guide](https://github.com/DisposableSoftware/style-guide).

## License

MIT, see [LICENSE](LICENSE).
