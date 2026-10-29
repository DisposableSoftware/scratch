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

- **Albums**: a grid of every album, your starred ones first under Favourites. Pick how
  many sit in a row, from 1 to 5.
- **Album screen**: cover, info, and the tracks, grouped by disc when there's more than one.
  Play or Shuffle the lot.
- **Songs**: the plain list of every track.
- **Player**: a bar above the tab bar, lock screen and Control Center controls, and a
  choice of how the server transcodes what it streams.
- **Sign-in**: your password is never stored, only the token the Subsonic API asks for.

It talks to the server only through the [OpenSubsonic API](https://opensubsonic.netlify.app),
so other servers may work too. Navidrome is the one it's tested against. No offline
downloads, playlists, scrobbling or iPad layout; see the non-goals in
[`spec/product.md`](spec/product.md).

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

## License

MIT, see [LICENSE](LICENSE).
