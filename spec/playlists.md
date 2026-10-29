# Playlists

The Playlists tab and the screen for one playlist. They follow the Albums tab and the album screen ([albums.md](albums.md)), with a playlist's tracks in the order the server keeps them. Tracks and their art are as in [library.md](library.md) and [playback.md](playback.md). Playlists are shown, never changed: editing them is a non-goal (`spec/product.md`).

## The Playlists grid

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLST-1` | The Playlists tab lists the server's playlists in a grid ordered by name, each cell showing the playlist's cover art, name and number of tracks. | planned | `PlaylistGatewayTests`, `PlaylistsViewModelTests`; `manual:` live screenshot of the grid |
| `PLST-2` | The grid has the number of columns of the **Albums per row** setting (`ALB-17`) and re-lays at once when it changes (`ALB-18`). | planned | `PlaylistsViewModelTests`; `manual:` live screenshot at 1, 2 and 5 per row |
| `PLST-3` | While the first load runs the tab shows a progress indicator. A load error shows its message with **Retry**, and a server with no playlists says so. | planned | `PlaylistsViewModelTests` |
| `PLST-4` | Pull to refresh reloads the playlists, keeping the grid on screen meanwhile. | planned | `PlaylistsViewModelTests`; the pull gesture itself is unchecked (no UI automation), as for `LIB-3` |
| `PLST-5` | Each cell's cover comes from `getCoverArt` at the size it is shown (scaled for the screen) and is cached like the track covers (`LIB-5`). A playlist without art shows a placeholder. | planned | `PlaylistsViewModelTests`; `manual:` live screenshot of the grid |
| `PLST-6` | Tapping a playlist pushes its screen onto the Playlists tab, and back returns to the grid where it was. | planned | `PlaylistsViewModelTests`, `PushStackHostTests`; the push and the swipe back on the real stack are in the verification backlog |

## The playlist screen

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLST-7` | The playlist screen shows, from the top, the playlist's cover art large; its info: name, owner, number of tracks and total duration, each shown only when the server has it; then the **Play** and **Shuffle** actions, then the tracks in the playlist's own order, each with its position, title, artist and duration. | planned | `PlaylistViewModelTests`, `PlaylistGatewayTests`; `manual:` live screenshot of a real playlist |
| `PLST-8` | Tapping a track plays it and queues the tracks after it in the playlist's order. **Play** plays the playlist from its first track and queues the rest. **Shuffle** plays all of its tracks once, in a random order (`PLAY-9`). | planned | `PlaylistViewModelTests`, `PlaybackUseCaseTests`; tapping on the real screen is in the verification backlog |
| `PLST-9` | A track the user has starred shows the heart of `LIB-7` left of its duration. The track numbers, durations and buttons keep the side margins of `ALB-19`, and Play's label the contrast of `LOOK-9`. | planned | `PlaylistGatewayTests`, `PlaylistViewModelTests`, `PlaylistLayoutTests` (draws the real screen and measures it, as `AlbumLayoutTests` does) |
| `PLST-10` | While the playlist loads its screen shows a progress indicator, and a load error shows its message with **Retry**. A playlist with no tracks says so. | planned | `PlaylistViewModelTests` |
| `PLST-11` | A playlist or Playlists-tab request that the server rejects as unauthorised (Subsonic error 40 or 41) returns the user to setup with the URL and username filled in, as for the track list (`SRV-6`). | planned | `PlaylistsViewModelTests`, `PlaylistViewModelTests` |

## Implementation notes

- Playlists come from `getPlaylists` in one request (the server doesn't page it), and a playlist's tracks from `getPlaylist` (`entry`). The cover is the playlist's `coverArt`.
- The same song can appear in a playlist more than once, so a row is identified by its position, not its track ID.
- There is no Favourites section at the top, unlike Albums (`ALB-3`): Subsonic has no favourite playlists, and the user chose to leave it out. Starred songs show only as hearts.
- The playlist screen shows the grid's cover and info at once, then refreshes from `getPlaylist`, and loads again each time it's pushed, as the album screen does. A `.push` carries the key `playlist:<id>`.
- The setting keeps its name, **Albums per row**, though it also sets this grid.
