# Roadmap

The order of approved work: `planned` requirements, and `partial` ones with a known bug from `/bug`. Change it here when priorities change. `/implement` works through this file: the verification backlog first, then the requirements in the order listed.

1. `ALB-8`, `ALB-9`, `ALB-10`, `ALB-11`, `ALB-15`: the album screen, pushed from the grid, with its info, discs, track rows and states.
2. `ALB-12`, `ALB-13`: tapping a track and Play.
3. `PLAY-9`, `ALB-14`: shuffle.
4. `ALB-16`: a rejected album request returns to setup.

## Verification backlog

Built requirements that are not fully verified. Clear these before starting new planned work.

- `ALB-1`, `PLAY-2`, `LIB-6`: in the simulator, launch signed in and check Albums is first and tapping Songs loads the track list; start a track and check the now-playing bar shows above the tab bar on both tabs, that tapping it opens the player and that its buttons are reachable with VoiceOver; sign out and check the bar goes; open settings from both tabs.
- `ALB-18`, `ALB-17`: in the simulator, scroll the Albums grid partway, open settings, change albums per row, close the sheet, and check the grid is still loaded with the same covers and the choice sticks after a relaunch.
- `PLAY-3`: in the simulator, tap a track, then tap the now-playing bar and check the player opens and its scrubber seeks; with VoiceOver on, check the bar's two buttons are reachable and labelled. (`PLAY-2`'s own check moved to its row when it was reworded for the tab bar.)
- `PLAY-6`, `PLAY-7`: on a device or the simulator, start a track, lock the screen and check it keeps playing and the lock screen shows it with working play/pause, next, previous and scrubbing; take a call (or play audio in another app) and check it pauses and comes back; unplug headphones and check it pauses.
- `SRV-7`, `TRANS-1`, `TRANS-2`: in the simulator, open settings and check both sections offer Original, MP3 and AAC and the bitrates, that the bitrate is disabled for Original, that Done closes the sheet, and that Sign Out returns to an empty setup screen. (`ImageRenderer` can't draw a `Form`, so there's no snapshot. `LIB-6`'s check, from both tabs, is on its row.)
- `TOOL-8`: push `main` from a terminal after a row becomes `done`, and check the hook offers the release, opens the notes in the editor and asks before pushing.
