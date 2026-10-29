# Albums

The Albums tab, and the screen for one album. Tracks and their art are the same as in [library.md](library.md) and [playback.md](playback.md). Favourites are shown, never changed: editing stars is still a non-goal.

## The tab bar

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ALB-1` | Once signed in, the app's main screen is a tab bar with **Albums** and **Songs**, and it opens on Albums. Songs is the track list of `LIB-1`. | partial: not tapped in the simulator yet; see the verification backlog | `manual:` live screenshot of a signed-in launch: Albums first with both tabs; tapping Songs is in the verification backlog |

## The Albums grid

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ALB-2` | The Albums tab lists the server's albums in a grid, each cell showing the album's cover art, name and artist. | done | `AlbumsViewModelTests`, `AlbumGatewayTests`; `manual:` live screenshot of the grid, with covers, names and artists |
| `ALB-3` | Albums the user has starred on the server appear first, in a **Favourites** section ordered by name, and aren't repeated in the section below. With none starred, there is no Favourites section. | done | `AlbumUseCaseTests`, `AlbumsViewModelTests`, `AlbumGatewayTests`; `manual:` live screenshot of the Favourites section, and `LiveServerTests.favouritesComeFirstAndAreNotRepeated` |
| `ALB-4` | The other albums follow in an **All Albums** section ordered by album name. They load in pages of 100, and the next page loads when the grid scrolls near its end, until the server returns a short page. | done | `AlbumUseCaseTests`, `AlbumsViewModelTests`, `AlbumGatewayTests`; `LiveServerTests.albumsPageInByName` pages a real server; live screenshot shows the header |
| `ALB-5` | Pull to refresh reloads the favourites and the first page, keeping the grid on screen meanwhile. | done | `AlbumsViewModelTests`, `AlbumUseCaseTests`; the pull gesture itself is unchecked (no UI automation), as for `LIB-3` |
| `ALB-6` | While the first load runs the tab shows a progress indicator. A load error shows its message with **Retry**, and a server with no albums says so. | done | `AlbumsViewModelTests` |
| `ALB-7` | Each cell's cover comes from `getCoverArt` at the size it is shown (scaled for the screen) and is cached like the track covers (`LIB-5`). An album without art shows a placeholder. | done | `AlbumsViewModelTests`, `CoverArtGatewayTests`; `manual:` live screenshot of the grid |
| `ALB-8` | Tapping an album pushes its screen onto the Albums tab, and back returns to the grid where it was. | partial: the push, the swipe back and the tap on the real navigation stack aren't checked by hand yet; see the verification backlog | `AlbumsViewModelTests`, `PushStackHostTests` |
| `ALB-17` | Settings has an **Albums per row** choice from 1 to 5, defaulting to 2, which sets the number of columns in both the Favourites and All Albums sections. | done | `DisplayUseCaseTests`, `AlbumsViewModelTests`, `SettingsViewModelTests`; `manual:` `scripts/manual/live-connect.sh` screenshots the grid at 5, 1 and 2 per row |
| `ALB-18` | The choice is saved across launches, and changing it re-lays the grid at once without reloading it. | done | `SettingsGatewayTests`, `DisplayUseCaseTests`, `AlbumsViewModelTests`; the launch screenshots read the setting at start; changing it with the grid scrolled partway, from the sheet, is in the verification backlog |
| `ALB-19` | On the album screen the tracks keep the same side margins as the Play and Shuffle buttons: the track numbers are left-aligned, so the first digit of every number starts, and every duration ends, 16 pt in from the screen's edges, whatever the number of digits. | done | `AlbumLayoutTests` (draws the real screen, 12 tracks, and measures the leftmost and rightmost drawn edge of the buttons and of the tracks); `manual:` the picture it writes (`alb19-album.png`) when `scripts/manual/snapshots.sh` runs |

## The album screen

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `ALB-9` | The album screen shows, from the top, the album's cover art large; its info: name, artist, year, genre, number of tracks and total duration, each shown only when the server has it; then the **Play** and **Shuffle** actions, then the tracks. | done | `AlbumViewModelTests`; `manual:` `scripts/manual/live-connect.sh` renders the real screen of a multi-disc and a single-disc album with Play and Shuffle (`alb9-*.png`) |
| `ALB-10` | Tracks are in disc and track-number order. An album with more than one disc groups them under a header per disc, "Disc 2", or "Disc 2 · Development" when the server names the disc. A single-disc album has no headers. | done | `AlbumUseCaseTests`, `AlbumDetailTests`, `AlbumViewModelTests`, `AlbumGatewayTests`; `LiveServerTests.albumScreensShowTracksByDisc` and its screenshot of the multi-disc Chrono Cross soundtrack |
| `ALB-11` | Each track row shows its track number, title and duration, and its artist when that differs from the album's artist. | done | `AlbumViewModelTests`; live screenshots of both album screens |
| `ALB-12` | Tapping a track plays it and queues the tracks after it, in disc and track order across discs. | done | `AlbumViewModelTests`, `PlaybackUseCaseTests`; tapping a track on the real screen is in the verification backlog |
| `ALB-13` | **Play** plays the album from its first track and queues the rest in order. | done | `AlbumViewModelTests`; tapping Play on the real screen is in the verification backlog |
| `ALB-14` | **Shuffle** plays all of the album's tracks once, in a random order (`PLAY-9`). | done | `AlbumViewModelTests`, `PlaybackUseCaseTests`; tapping Shuffle on the real screen is in the verification backlog |
| `ALB-15` | While the album loads its screen shows a progress indicator, and a load error shows its message with **Retry**. | done | `AlbumViewModelTests` |
| `ALB-16` | An album or Albums-tab request that the server rejects as unauthorised (Subsonic error 40 or 41) returns the user to setup with the URL and username filled in, as for the track list (`SRV-6`). | done | `AlbumsViewModelTests`, `AlbumViewModelTests`, `AlbumUseCaseTests`; `LiveServerTests.staleCredentialsAreRejectedByAlbumRequests` checks a real stale album request is rejected |

## Implementation notes

- The Songs tab is the "library screen" that `LIB-1` to `LIB-5` describe; those rows are unchanged.
- Albums come from `getAlbumList2` with `type=alphabeticalByName`, `size=100` and `offset`. Favourites come from `getStarred2` in one request, and the `album` entries are the starred albums. An album's tracks and discs come from `getAlbum`, in one request: albums here run to 67 tracks.
- The next page's `offset` counts the albums the server has returned, not those shown, so taking the favourites out of All Albums skips nothing. A favourited album is removed from the lower section by ID. An album starred on the server since the last refresh may appear in both until the next refresh.
- The albums per row is saved with the other settings. Anything saved that isn't a number, or a numeric string, counts as nothing saved and gives the default of 2; a number outside 1 to 5 is brought into it. A `-settings.albumsPerRow N` launch argument stands in for the saved value for that launch, as Cocoa reads any `-key value` pair, and `scripts/manual/live-connect.sh` uses it to screenshot the grid at 1, 2 and 5.
- When the column count changes the grid keeps its scroll offset in points, nothing anchors it to an album, so the user may land on different albums.
- Covers are tracked per album: each is held at the size it was fetched at. A request for about that size or smaller keeps it (cells a pixel apart don't fetch twice), a larger one fetches it again, and a size asked for while a fetch runs is fetched after it. A cover that fails is asked for again the next time its cell reports its size, which a cell does when it appears. The tab keeps the 300 most recent decoded covers.
- The **All Albums** header shows only when a Favourites section is above it and there are albums below it. With no favourites the grid is just the albums.
- A refresh keeps the grid on screen, works on the empty screen too, and keeps the covers it has. A next page still out from before it is dropped when it lands, and doesn't stop the new list loading its own. If the refresh fails, the grid gives way to the error with Retry, as for the track list (`LIB-3`).
- The favourites are ordered by the app, by name with numbers read as numbers and case ignored, and the albums below by the server's own collation, so the two sections can order a pair of names differently.
- A page made up only of favourites shows nothing new, so the next is taken at once, up to ten pages in a row. If one of those pages fails, the whole first load fails: the tab shows the error, and Retry reloads from the start.
- The favourites and the first page must both load: if either fails, the tab shows the error with Retry.
- Disc titles come from `getAlbum`'s `discTitles`, matched by disc number. A track without a `discNumber` is on disc 1.
- A pushed screen is a `NavigationDestination` (a `.push` case) that goes through the Coordinator, like the sheets (`ARCH-12`, `ARCH-13`). Views have no `NavigationLink`, so the stack's path is owned by the host in `App/`, and the album screen is built by a ViewModel-local Route from the Albums ViewModel.
- A `.push` carries a key naming its screen (`album:<id>`), and the host ignores a push whose key is the screen already on top, so a double tap pushes one screen. The same album can be pushed again once something else is on top.
- The album screen shows the grid's cover and info at once, loads the tracks and refreshes the info from `getAlbum`, and loads again each time it's pushed (nothing is cached). A second appearance while it loads waits for the first. Its cover is fetched at the width it's shown at, with the same keep-smaller, refetch-larger, fetch-after rules as the grid's. The album's name is in the navigation bar and again under the cover.
- Play is disabled until the tracks have loaded. An album with no tracks says so.
- Tab selection is the container's own state, not a route: nothing navigates between tabs. A tab loads when it is first shown, so Songs no longer loads at launch.
- There is one now-playing bar, in the tab view's bottom accessory, so it sits above the tab bar and also shows on the album screen. It draws no background of its own: the accessory supplies it. Its ViewModel is shared with the player.
- The grid has as many columns as the setting says, with equal gaps, and the covers fill their column's width. Each cell is a square cover with the name and artist below it, each on one line and truncated, so at 4 or 5 per row the text is small. The covers are fetched at the size the column gives them.
- The setting lives with the other settings (`UserDefaultsSettingsGateway`), and the Albums ViewModel reads it through the same use case. A change while the grid is showing reaches it at once, so the sheet's own result is visible behind it.
