# Library

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `LIB-1` | The library screen lists the server's tracks, each with its cover art thumbnail, title, artist, album and duration. | done | `LibraryViewModelTests`, `LibraryGatewayTests`; `manual:` `scripts/manual/live-connect.sh` screenshot shows real tracks with art, artist · album and m:ss |
| `LIB-2` | Tracks load in pages of 100 (`search3` with an empty query, `songCount` and `songOffset`), and the next page loads when the list scrolls near its end, until the server returns a short page. | done | `LibraryUseCaseTests`, `LibraryViewModelTests`, `LibraryGatewayTests` |
| `LIB-3` | Pull to refresh reloads the list from the first page. | done | `LibraryViewModelTests`, `LibraryUseCaseTests`; the pull gesture itself is unchecked (no UI automation) |
| `LIB-4` | While the first page loads, the screen shows a progress indicator. A load error shows its message with **Retry**, and an empty library says so. | done | `LibraryViewModelTests` |
| `LIB-5` | Cover art comes from `getCoverArt` at the size it is shown (scaled for the screen), and is cached in memory for the session. | done | `CoverArtGatewayTests`, `CoverArtUseCaseTests`, `LibraryViewModelTests`; `manual:` live screenshot |
| `LIB-6` | A settings button on the library screen opens settings (transcoding, server, sign out) as a sheet. | partial: the sheet has transcoding only; server and sign out come with `SRV-7` | `LibraryViewModelTests`, `SettingsViewModelTests`; the sheet itself is in the verification backlog |

## Implementation notes

- OpenSubsonic doesn't promise `search3`'s order is stable, and a library scan between pages can shift it. A track that comes round again on a later page is dropped rather than shown twice.
- A pull to refresh keeps the list on screen while it reloads, and works on the empty screen too. No next page starts while a reload runs, because its offset would be the old list's length. A page, or a page's failure, from before a reload is dropped.
- Only one first-page load runs at a time, so two appearances while it loads can't flash "No tracks".
- Covers are fetched at the row's size in pixels (48pt × the screen scale). The gateway keeps the bytes in an `NSCache` (64 MB) for the session. The screen keeps the 200 most recently decoded covers, decoded off the main thread, and a row whose cover was dropped or failed to load asks again when it reappears.
- Any 200 answer to `getCoverArt` that isn't a Subsonic error counts as the image, whatever its Content-Type: some servers send none.
