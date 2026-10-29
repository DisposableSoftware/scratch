# Roadmap

The order of approved work: `planned` requirements, and `partial` ones with a known bug from `/bug`. Change it here when priorities change. `/implement` works through this file: the verification backlog first, then the requirements in the order listed.

1. `TRANS-1`, `TRANS-2`, `TRANS-3`, `TRANS-4`, `TRANS-5`: the transcoding settings and stream URLs.
2. `TRANS-6`, `PLAY-3`: quality in the player, which completes it.
3. `LIB-6`, `SRV-6`, `SRV-7`: the settings sheet, re-authentication and sign out.
4. `ARCH-16`: confirm every Router and UseCase has tests.

## Verification backlog

Built requirements that are not fully verified. Clear these before starting new planned work.

- `PLAY-2`, `PLAY-3`: in the simulator, tap a track, then tap the now-playing bar and check the player opens and its scrubber seeks; with VoiceOver on, check the bar's two buttons are reachable and labelled.
- `PLAY-6`, `PLAY-7`: on a device or the simulator, start a track, lock the screen and check it keeps playing and the lock screen shows it with working play/pause, next, previous and scrubbing; take a call (or play audio in another app) and check it pauses and comes back; unplug headphones and check it pauses.
- `TOOL-8`: push `main` from a terminal after a row becomes `done`, and check the hook offers the release, opens the notes in the editor and asks before pushing.
