# Roadmap

The order of approved work: `planned` requirements, and `partial` ones with a known bug from `/bug`. Change it here when priorities change. `/implement` works through this file: the verification backlog first, then the requirements in the order listed.

1. `SRV-3`, `SRV-5`: connecting, and the saved server.
2. `LIB-1`, `LIB-2`, `LIB-4`, `LIB-5`: the track list.
3. `LIB-3`: pull to refresh.
4. `PLAY-1`, `PLAY-4`, `PLAY-5`, `PLAY-8`: the queue and the player engine.
5. `PLAY-2`, `PLAY-3`: the now-playing bar and the player screen.
6. `PLAY-6`, `PLAY-7`: background audio, the lock screen and interruptions.
7. `TRANS-1`, `TRANS-2`, `TRANS-3`, `TRANS-4`, `TRANS-5`: the transcoding settings and stream URLs.
8. `TRANS-6`: quality in the player.
9. `LIB-6`, `SRV-6`, `SRV-7`: the settings sheet, re-authentication and sign out.
10. `ARCH-16`: confirm every Router and UseCase has tests.

## Verification backlog

Built requirements that are not fully verified. Clear these before starting new planned work.

- `TOOL-8`: push `main` from a terminal after a row becomes `done`, and check the hook offers the release, opens the notes in the editor and asks before pushing.
