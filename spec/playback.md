# Playback

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLAY-1` | Tapping a track plays it, and queues the tracks after it in the loaded list. | done | `PlaybackUseCaseTests`, `LibraryViewModelTests`; `manual:` live test streams a real track |
| `PLAY-2` | While a track is loaded, a now-playing bar at the bottom of the library shows its art, title and artist, with play/pause. | done | `PlayerViewModelTests`; `manual:` `scripts/manual/snapshots.sh` renders the bar playing and failed; tapping it in the simulator is in the verification backlog |
| `PLAY-3` | Tapping the bar opens the player: large art, title, artist, album, elapsed and remaining time, a scrubber, previous, play/pause, next, and the current stream quality (`TRANS-6`). | partial: everything but the stream quality, which arrives with `TRANS-6` | `PlayerViewModelTests`; `manual:` `scripts/manual/snapshots.sh` renders the player |
| `PLAY-4` | When a track ends, the next queued track plays. After the last one, playback stops at the start of that last track. | done | `PlaybackUseCaseTests` |
| `PLAY-5` | **Previous** restarts the current track when more than 3 seconds in, and otherwise plays the previous queued track. At the first track it restarts it. | done | `PlaybackUseCaseTests` |
| `PLAY-6` | Playback continues in the background and with the screen locked. The lock screen and Control Center show the track and offer play/pause, next, previous and scrubbing. | planned | `manual:` device or simulator lock screen |
| `PLAY-7` | An audio interruption (a call, another app) pauses playback, which resumes afterwards when the system says it should. Unplugging headphones or disconnecting Bluetooth audio pauses. | planned | `PlaybackUseCaseTests` |
| `PLAY-8` | If a stream fails to load or play, the player shows the error and playback stops. It doesn't skip silently. | done | `PlaybackUseCaseTests`, `PlayerViewModelTests`; `manual:` live test fails on a missing track; `scripts/manual/snapshots.sh` renders the failed bar and player |

## Implementation notes

- The queue holds the tapped track and the ones after it in the list as it was loaded then. Pages loaded later aren't added.
- After a failure (`PLAY-8`), the track stays failed: Next at the end of the queue and seeking do nothing, play/pause retries it, and Previous goes back one (or retries the first).
- Previous decides by the elapsed time the app shows, not AVPlayer's clock. A seek lands asynchronously, so two quick presses would otherwise restart twice.
- `AVPlayerAudioGateway` can't be unit-tested with `StubURLProtocol`, because AVPlayer loads outside URLSession's protocol classes. The live test in `scripts/manual/live-connect.sh` covers it against a real server: a track reaches ready and plays past a second, and a missing track fails.
- A stream that stalls mid-track (network loss) isn't reported until AVPlayer gives up on it and fails, which can take a while. Reporting stalls sooner needs its own row.
- The bar and the player share one `PlayerViewModel`, which mirrors `PlaybackState` (exposed read-only in intent as `PlaybackUseCase.state`). Opening the player is a ViewModel-local Route to a sheet.
- The bar's art and titles are one button that opens the player, with play/pause a separate button, so VoiceOver can reach both. A failed track shows "Couldn't play this track" in the bar too, and play/pause becomes "Try again".
- Dragging the scrubber moves only the shown position; the seek happens on release. A drag is dropped, without seeking, if the track changes or the player closes mid-drag. With no known duration the scrubber is disabled and the remaining time is hidden.
