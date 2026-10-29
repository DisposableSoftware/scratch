# Albums

The Albums tab, and the screen for one album. Tracks and their art are the same as in [library.md](library.md) and [playback.md](playback.md). Favourites are shown, never changed: editing stars is still a non-goal.

## The tab bar

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ALB-1` | Once signed in, the app's main screen is a tab bar with **Albums** and **Songs**, and it opens on Albums. Songs is the track list of `LIB-1`. | planned | `manual:` launch signed in and check both tabs, and that Albums is first |

## The Albums grid

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ALB-2` | The Albums tab lists the server's albums in a grid, each cell showing the album's cover art, name and artist. | planned | `AlbumsViewModelTests`, `AlbumGatewayTests`; `manual:` live screenshot |
| `ALB-3` | Albums the user has starred on the server appear first, in a **Favourites** section ordered by name, and aren't repeated in the section below. With none starred, there is no Favourites section. | planned | `AlbumUseCaseTests`, `AlbumsViewModelTests` |
| `ALB-4` | The other albums follow in an **All Albums** section ordered by album name. They load in pages of 100, and the next page loads when the grid scrolls near its end, until the server returns a short page. | planned | `AlbumUseCaseTests`, `AlbumsViewModelTests`, `AlbumGatewayTests` |
| `ALB-5` | Pull to refresh reloads the favourites and the first page, keeping the grid on screen meanwhile. | planned | `AlbumsViewModelTests`, `AlbumUseCaseTests` |
| `ALB-6` | While the first load runs the tab shows a progress indicator. A load error shows its message with **Retry**, and a server with no albums says so. | planned | `AlbumsViewModelTests` |
| `ALB-7` | Each cell's cover comes from `getCoverArt` at the size it is shown (scaled for the screen) and is cached like the track covers (`LIB-5`). An album without art shows a placeholder. | planned | `AlbumsViewModelTests`, `CoverArtGatewayTests`; `manual:` live screenshot |
| `ALB-8` | Tapping an album pushes its screen onto the Albums tab, and back returns to the grid where it was. | planned | `AlbumsViewModelTests`; `manual:` simulator check |
| `ALB-17` | Settings has an **Albums per row** choice from 1 to 5, defaulting to 2, which sets the number of columns in both the Favourites and All Albums sections. | planned | `AlbumsViewModelTests`, `SettingsViewModelTests`; `manual:` in the simulator, check 1, 2 and 5 per row |
| `ALB-18` | The choice is saved across launches, and changing it re-lays the grid at once without reloading it. | planned | `SettingsGatewayTests`, `AlbumsViewModelTests`; `manual:` change it with the grid scrolled partway and check the grid stays loaded |

## The album screen

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ALB-9` | The album screen shows, from the top, the album's cover art large; its info: name, artist, year, genre, number of tracks and total duration, each shown only when the server has it; then the **Play** and **Shuffle** actions, then the tracks. | planned | `AlbumViewModelTests`; `manual:` live screenshot |
| `ALB-10` | Tracks are in disc and track-number order. An album with more than one disc groups them under a header per disc, "Disc 2", or "Disc 2 · Development" when the server names the disc. A single-disc album has no headers. | planned | `AlbumUseCaseTests`, `AlbumViewModelTests`; `manual:` live screenshot of a multi-disc album |
| `ALB-11` | Each track row shows its track number, title and duration, and its artist when that differs from the album's artist. | planned | `AlbumViewModelTests`; `manual:` live screenshot |
| `ALB-12` | Tapping a track plays it and queues the tracks after it, in disc and track order across discs. | planned | `AlbumViewModelTests`, `PlaybackUseCaseTests` |
| `ALB-13` | **Play** plays the album from its first track and queues the rest in order. | planned | `AlbumViewModelTests` |
| `ALB-14` | **Shuffle** plays all of the album's tracks once, in a random order (`PLAY-9`). | planned | `AlbumViewModelTests` |
| `ALB-15` | While the album loads its screen shows a progress indicator, and a load error shows its message with **Retry**. | planned | `AlbumViewModelTests` |
| `ALB-16` | An album or Albums-tab request that the server rejects as unauthorised (Subsonic error 40 or 41) returns the user to setup with the URL and username filled in, as for the track list (`SRV-6`). | planned | `AlbumsViewModelTests`, `AlbumViewModelTests`; `manual:` live test: a stale-credential album request is rejected |

## Implementation notes

- The Songs tab is the "library screen" that `LIB-1` to `LIB-5` describe; those rows are unchanged.
- Albums come from `getAlbumList2` with `type=alphabeticalByName`, `size=100` and `offset`. Favourites come from `getStarred2` in one request, and the `album` entries are the starred albums. An album's tracks and discs come from `getAlbum`, in one request: albums here run to 67 tracks.
- The next page's `offset` counts the albums the server has returned, not those shown, so taking the favourites out of All Albums skips nothing. A favourited album is removed from the lower section by ID. An album starred on the server since the last refresh may appear in both until the next refresh.
- The favourites and the first page must both load: if either fails, the tab shows the error with Retry.
- Disc titles come from `getAlbum`'s `discTitles`, matched by disc number. A track without a `discNumber` is on disc 1.
- A pushed screen is a `NavigationDestination` (a `.push` case) that goes through the Coordinator, like the sheets (`ARCH-12`, `ARCH-13`). Views have no `NavigationLink`, so the stack's path is owned by the host in `App/`, and the album screen is built by a ViewModel-local Route from the Albums ViewModel.
- Tab selection is the container's own state, not a route: nothing navigates between tabs.
- There is one now-playing bar, above the tab bar, so it also shows on the album screen. Its ViewModel is shared with the player.
- The grid has as many columns as the setting says, with equal gaps, and the covers fill their column's width. Each cell is a square cover with the name and artist below it, each on one line and truncated, so at 4 or 5 per row the text is small. The covers are fetched at the size the column gives them.
- The setting lives with the other settings (`UserDefaultsSettingsGateway`), and the Albums ViewModel reads it through the same use case. A change while the grid is showing reaches it at once, so the sheet's own result is visible behind it.
