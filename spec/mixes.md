# Mixes

The **Me** tab: mixes of the user's own music, made on the device from their hearts, their plays and release dates. A mix is a queue the app builds and plays. It is never written to the server, since editing playlists is a non-goal (`spec/product.md`). The model is the on-device language model in iOS (the Foundation Models framework), so no dependency is added and no track data goes to any service but the user's own server.

## The tab

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `MIX-1` | The tab bar has a fourth tab, **Me**, after Songs, only while the on-device language model is available. When it isn't (no Apple Intelligence, it's turned off, or the model isn't ready), the tab is hidden, and it comes back when the model becomes available. | planned | `MixesViewModelTests`, `MainViewModelTests` (the tab follows a model that comes and goes); `manual:` on a simulator or device with the model available, and on one without |
| `MIX-2` | The Me tab lists the mixes it has as cards in this order: **Hearts**, **Most played**, **On this day**, each with its name, a one-line description, its number of tracks and the cover of its first track. A mix with no tracks has no card. | planned | `MixesViewModelTests`; `manual:` screenshot of the tab with real mixes |
| `MIX-3` | The Me tab loads its mixes when it is first shown, shows a progress indicator while they are made, and, with no mix to show, says there is nothing to mix yet. A server error shows its message with **Retry**. | planned | `MixesViewModelTests` |
| `MIX-4` | Pull to refresh makes the mixes again, from the server's current hearts and plays, keeping the old cards on screen meanwhile. | planned | `MixesViewModelTests`; the pull gesture itself is unchecked (no UI automation), as for `LIB-3` |

## Making a mix

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `MIX-5` | Each mix starts from a shortlist of at most 60 tracks chosen by rule: **Hearts** from the tracks the user has starred, **Most played** from the tracks with the highest play count, and **On this day** from the tracks of albums whose release date has today's month and day. | planned | `MixUseCaseTests`, `MixGatewayTests` |
| `MIX-6` | The model is given the shortlist (each track's title, artist, album, year and genre, as far as the server has them) and asked for the tracks that fit the mix, in the order to play them, at most 25, with a name and a one-line description. | planned | `MixUseCaseTests` (against a model mock); `manual:` a real model on the simulator or a device |
| `MIX-7` | Only tracks of the shortlist can end up in a mix: an ID the model returns that isn't in the shortlist is dropped, and a track it returns twice is kept once. | planned | `MixUseCaseTests` |
| `MIX-8` | When the model fails for a mix (an error, a refusal, or no usable tracks), that mix is the first 25 tracks of its shortlist in the rule's order, named for its rule ("Hearts", "Most played", "On this day"), instead of no mix at all. | planned | `MixUseCaseTests` |
| `MIX-9` | The mixes are kept on the phone until they are made again: leaving the tab and coming back doesn't regenerate them, and signing out discards them. | planned | `MixUseCaseTests`, `SessionUseCaseTests` |

## The mix screen

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `MIX-10` | Tapping a mix pushes its screen onto the Me tab, which shows the mix's name and description, **Play** and **Shuffle**, then its tracks in order, each with its position, title, artist, duration and the heart of `LIB-7`, on the margins of `ALB-19`. | planned | `MixViewModelTests`, `MixLayoutTests` (draws the real screen and measures it, as `AlbumLayoutTests` does) |
| `MIX-11` | Tapping a track plays it and queues the tracks after it in the mix's order. **Play** plays the mix from its first track. **Shuffle** plays all of its tracks once, in a random order (`PLAY-9`). | planned | `MixViewModelTests`, `PlaybackUseCaseTests`; tapping on the real screen is in the verification backlog |
| `MIX-12` | A request for the Me tab or a mix that the server rejects as unauthorised (Subsonic error 40 or 41) returns the user to setup with the URL and username filled in, as for the track list (`SRV-6`). | planned | `MixesViewModelTests`, `MixViewModelTests` |

## Implementation notes

- The model is the Foundation Models framework's `SystemLanguageModel`; the tab is shown when its `availability` is `.available`, checked at launch and whenever the app becomes active. Only a Gateway imports the framework, behind a protocol the tests mock. The simulator may not have the model, in which case the tab is hidden and the model's own behaviour can only be seen on a device.
- Its context is small, so a shortlist is compact (one short line per track) and capped at 60 tracks. The model answers in a typed structure (a name, a description and a list of track IDs) with guided generation, so nothing is parsed out of prose.
- Tracks gain what the shortlist needs from the server: `playCount`, the year, the genre, and `starred` (already read). Hearts come from `getStarred2`, which already lists starred songs. Most played comes from `getAlbumList2` with `type=frequent` and then those albums' tracks (`getAlbum`) sorted by play count, since no request lists songs by play count. On this day scans `getAlbumList2` pages (`LIB-2`'s size of 100) for the OpenSubsonic `releaseDate` (year, month, day) and stops after 20 pages, so a very large library is only partly scanned. Many albums have only a year, so this mix is often empty; that is expected, and it has no card then (`MIX-2`).
- Making the mixes asks the model three times at most, one mix at a time, so the tab shows each card when it is ready.
- A mix keeps no server identity: its screen is pushed with the key `mix:<kind>`, and its tracks come from the phone's copy, not from a request.
