# Library

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `LIB-1` | The library screen lists the server's tracks, each with its cover art thumbnail, title, artist, album and duration. | planned | `LibraryViewModelTests`; `manual:` screenshot against a server |
| `LIB-2` | Tracks load in pages of 100 (`search3` with an empty query, `songCount` and `songOffset`), and the next page loads when the list scrolls near its end, until the server returns a short page. | planned | `LibraryUseCaseTests` |
| `LIB-3` | Pull to refresh reloads the list from the first page. | planned | `LibraryUseCaseTests` |
| `LIB-4` | While the first page loads, the screen shows a progress indicator. A load error shows its message with **Retry**, and an empty library says so. | planned | `LibraryViewModelTests` |
| `LIB-5` | Cover art comes from `getCoverArt` at the size it is shown (scaled for the screen), and is cached in memory for the session. | planned | `CoverArtGatewayTests` |
| `LIB-6` | A settings button on the library screen opens settings (transcoding, server, sign out) as a sheet. | planned | `manual:` simulator check |
