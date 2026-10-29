# Playback

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLAY-1` | Tapping a track plays it, and queues the tracks after it in the loaded list. | done | `PlaybackUseCaseTests`, `LibraryViewModelTests`; `manual:` live test streams a real track |
| `PLAY-2` | While a track is loaded, a now-playing bar shows its art, title and artist, with play/pause, at the bottom of every tab and of the album screen, above the tab bar. | planned | `PlayerViewModelTests`; `manual:` `scripts/manual/snapshots.sh` renders the bar playing and failed; in the simulator, check it shows above the tab bar on Albums, Songs and an album screen, and that tapping it opens the player |
| `PLAY-3` | Tapping the bar opens the player: large art, title, artist, album, elapsed and remaining time, a scrubber, previous, play/pause, next, and the current stream quality (`TRANS-6`). | done | `PlayerViewModelTests`; `manual:` `scripts/manual/snapshots.sh` renders the player |
| `PLAY-4` | When a track ends, the next queued track plays. After the last one, playback stops at the start of that last track. | done | `PlaybackUseCaseTests` |
| `PLAY-5` | **Previous** restarts the current track when more than 3 seconds in, and otherwise plays the previous queued track. At the first track it restarts it. | done | `PlaybackUseCaseTests` |
| `PLAY-6` | Playback continues in the background and with the screen locked. The lock screen and Control Center show the track and offer play/pause, next, previous and scrubbing. | done | `PlaybackUseCaseTests`, `SystemGatewayTests`; lock screen and background play by hand are in the verification backlog |
| `PLAY-7` | An audio interruption (a call, another app) pauses playback, which resumes afterwards when the system says it should. Unplugging headphones or disconnecting Bluetooth audio pauses. | done | `PlaybackUseCaseTests`, `SystemGatewayTests`; a real call or another app's audio is in the verification backlog |
| `PLAY-8` | If a stream fails to load or play, the player shows the error and playback stops. It doesn't skip silently. | done | `PlaybackUseCaseTests`, `PlayerViewModelTests`; `manual:` live test fails on a missing track; `scripts/manual/snapshots.sh` renders the failed bar and player |
| `PLAY-9` | Playing a list shuffled queues every track in it once, in a random order, and starts with the first of them. Next and Previous follow that order, and there is no shuffle mode afterwards: the next list played is in order again. | planned | `PlaybackUseCaseTests` |

## Implementation notes

- The queue holds the tapped track and the ones after it in the list as it was loaded then. Pages loaded later aren't added. "The list" is whichever one the track was tapped in: the Songs tab, or an album (`ALB-12`).
- A shuffled queue is every track of the list once, in an order chosen when it's started: a Fisher–Yates shuffle with a random generator the use case is given, so tests can fix the order. Shuffling an album again re-shuffles it.
- After a failure (`PLAY-8`), the track stays failed: Next at the end of the queue and seeking do nothing, play/pause retries it, and Previous goes back one (or retries the first).
- Previous decides by the elapsed time the app shows, not AVPlayer's clock. A seek lands asynchronously, so two quick presses would otherwise restart twice.
- `AVPlayerAudioGateway` can't be unit-tested with `StubURLProtocol`, because AVPlayer loads outside URLSession's protocol classes. The live test in `scripts/manual/live-connect.sh` covers it against a real server: a track reaches ready and plays past a second, and a missing track fails.
- A stream that stalls mid-track (network loss) isn't reported until AVPlayer gives up on it and fails, which can take a while. Reporting stalls sooner needs its own row.
- The bar and the player share one `PlayerViewModel`, which mirrors `PlaybackState` (exposed read-only in intent as `PlaybackUseCase.state`). Opening the player is a ViewModel-local Route to a sheet.
- The bar's art and titles are one button that opens the player, with play/pause a separate button, so VoiceOver can reach both. A failed track shows "Couldn't play this track" in the bar too, and play/pause becomes "Try again".
- Dragging the scrubber moves only the shown position; the seek happens on release. A drag is dropped, without seeking, if the track changes or the player closes mid-drag. With no known duration the scrubber is disabled and the remaining time is hidden.
- Background playback needs `UIBackgroundModes` `audio` in `Info.plist` and the `.playback` audio session category, which the audio gateway sets when it's built. The session is activated on load and play, and released with `notifyOthersOnDeactivation` when a track fails. `setActive` blocks the main actor briefly; iOS 27's asynchronous `activate` is the alternative if that shows.
- iOS 27 replaced the interruption notification. An interruption is now the system deactivating the session (`didBecomeInactiveNotification`, source `.system`), and the system says separately whether to resume (`resumptionRecommendationNotification`). A deactivation because the route disconnected is left to the route-change notification, which pauses without arming a resume.
- Playback resumes after an interruption only if it was playing when the interruption began, it is still paused, and the system recommends it. Pausing, a failure, losing the output, or the queue ending meanwhile cancels the resume.
- The lock screen moves its own clock along while the rate is 1, so time ticks aren't published. While AVPlayer is waiting for the stream, the lock screen is told the track isn't moving. A pause or resume publishes the last tick's time, which can be up to half a second behind.
- The lock screen shows no cover art: `MPMediaItemArtwork` needs a `UIImage`, and Gateways don't import UIKit (`ARCH-4`).
