# Playlists

The Playlists tab and the screen for one playlist. They follow the Albums tab and the album screen ([albums.md](albums.md)), with a playlist's tracks in the order the server keeps them. Tracks and their art are as in [library.md](library.md) and [playback.md](playback.md). Playlists are shown, never changed: editing them is a non-goal (`spec/product.md`).

## The Playlists grid

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLST-1` | The Playlists tab lists the server's playlists in a grid ordered by name, each cell showing the playlist's cover art, name and, when the server gives it, number of tracks. | done | `PlaylistGatewayTests`, `PlaylistUseCaseTests`, `PlaylistsViewModelTests`; `manual:` live screenshot of the grid on a real server (`plst1-playlists.png`), `LiveServerTests.playlistsListAndShowTheirTracks` (the public demo server) |
| `PLST-2` | The grid has the number of columns of the **Albums per row** setting (`ALB-17`) and re-lays at once when it changes (`ALB-18`). | done | `PlaylistsViewModelTests` (the grid follows the setting at once); the setting's own tests are `ALB-17` and `ALB-18`'s |
| `PLST-3` | While the first load runs the tab shows a progress indicator. A load error shows its message with **Retry**, and a server with no playlists says so. | done | `PlaylistsViewModelTests` |
| `PLST-4` | Pull to refresh reloads the playlists, keeping the grid on screen meanwhile. | done | `PlaylistsViewModelTests`; the pull gesture itself is unchecked (no UI automation), as for `LIB-3` |
| `PLST-5` | Each cell's cover comes from `getCoverArt` at the size it is shown (scaled for the screen) and is cached like the track covers (`LIB-5`). A playlist without art shows the placeholder the album covers use. | done | `PlaylistsViewModelTests`; `manual:` live screenshot of the grid with real covers (`plst1-playlists.png`) |
| `PLST-6` | Tapping a playlist pushes its screen onto the Playlists tab, and back returns to the grid where it was. | partial: the push, the swipe back and the tap on the real tab stack aren't checked by hand yet; see the verification backlog | `PlaylistsViewModelTests`, `PushStackHostTests` (each tab has its own path) |

## The playlist screen

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLST-7` | The playlist screen shows, from the top, the playlist's cover art large; its info: name, owner, number of tracks and total duration, each shown only when the server has it; then the **Play** and **Shuffle** actions, then the tracks in the playlist's own order, each with its position, title, artist and duration. | done | `PlaylistViewModelTests`, `PlaylistGatewayTests`; `manual:` live screenshot of a real playlist (`plst7-playlist.png`), `LiveServerTests.playlistsListAndShowTheirTracks` (the public demo server) |
| `PLST-8` | Tapping a track plays it and queues the tracks after it in the playlist's order. **Play** plays the playlist from its first track and queues the rest. **Shuffle** plays all of its tracks once, in a random order (`PLAY-9`). | partial: tapping a track, Play and Shuffle on the real screen aren't checked by hand yet; see the verification backlog | `PlaylistViewModelTests` (including tapping the second copy of a song that is in a playlist twice) |
| `PLST-9` | A track the user has starred shows the heart of `LIB-7` left of its duration. The track numbers, durations and buttons keep the side margins of `ALB-19`, and Play's label the contrast of `LOOK-9`. | done | `PlaylistGatewayTests`, `PlaylistViewModelTests`, `PlaylistLayoutTests` (draws the real screen: a heart in the starred track's row only, and the margins of `ALB-19`); Play's label is the shared header's, checked for `LOOK-9` by `AlbumLayoutTests`; `manual:` the live screenshot shows hearts on the starred tracks of a real playlist |
| `PLST-10` | While the playlist loads its screen shows a progress indicator, and a load error shows its message with **Retry**. A playlist with no tracks says so. | done | `PlaylistViewModelTests` |
| `PLST-11` | A playlist or Playlists-tab request that the server rejects as unauthorised (Subsonic error 40 or 41) returns the user to setup with the URL and username filled in, as for the track list (`SRV-6`). | done | `PlaylistsViewModelTests`, `PlaylistViewModelTests` |

## Implementation notes

- Playlists come from `getPlaylists` in one request (the server doesn't page it), and a playlist's tracks from `getPlaylist` (`entry`). The cover is the playlist's `coverArt`.
- The same song can appear in a playlist more than once, so a row is identified by its position, not its track ID.
- There is no Favourites section at the top, unlike Albums (`ALB-3`): Subsonic has no favourite playlists, and the user chose to leave it out. Starred songs show only as hearts.
- The playlist screen shows the grid's cover and info at once, then fills in the owner, count and duration from `getPlaylist` (the name and cover stay as the grid showed them), and loads again each time it's pushed, as the album screen does. A `.push` carries the key `playlist:<id>`.
- The setting keeps its name, **Albums per row**, though it also sets this grid.
