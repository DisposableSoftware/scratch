# Playback

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `PLAY-1` | Tapping a track plays it, and queues the tracks after it in the loaded list. | planned | `PlaybackUseCaseTests` |
| `PLAY-2` | While a track is loaded, a now-playing bar at the bottom of the library shows its art, title and artist, with play/pause. | planned | `manual:` simulator check |
| `PLAY-3` | Tapping the bar opens the player: large art, title, artist, album, elapsed and remaining time, a scrubber, previous, play/pause, next, and the current stream quality (`TRANS-6`). | planned | `manual:` simulator check |
| `PLAY-4` | When a track ends, the next queued track plays. After the last one, playback stops at the start of that last track. | planned | `PlaybackUseCaseTests` |
| `PLAY-5` | **Previous** restarts the current track when more than 3 seconds in, and otherwise plays the previous queued track. At the first track it restarts it. | planned | `PlaybackUseCaseTests` |
| `PLAY-6` | Playback continues in the background and with the screen locked. The lock screen and Control Center show the track and offer play/pause, next, previous and scrubbing. | planned | `manual:` device or simulator lock screen |
| `PLAY-7` | An audio interruption (a call, another app) pauses playback, which resumes afterwards when the system says it should. Unplugging headphones or disconnecting Bluetooth audio pauses. | planned | `PlaybackUseCaseTests` |
| `PLAY-8` | If a stream fails to load or play, the player shows the error and playback stops. It doesn't skip silently. | planned | `PlaybackUseCaseTests` |
