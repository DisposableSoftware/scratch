# Roadmap

The order of approved work: `planned` requirements, and `partial` ones with a known bug from `/bug`. Change it here when priorities change. `/implement` works through this file: the verification backlog first, then the requirements in the order listed.

1. `ARCH-11`, `SRV-1`: `AppRouter`, the view factory and the app's RoutingUseCase, with setup and library as the first steps.
2. `PROD-3`, `SRV-2`, `SRV-4`: the Subsonic request builder and server URL handling.
3. `SRV-3`, `SRV-5`: connecting, and the saved server.
4. `LIB-1`, `LIB-2`, `LIB-4`, `LIB-5`: the track list.
5. `LIB-3`: pull to refresh.
6. `PLAY-1`, `PLAY-4`, `PLAY-5`, `PLAY-8`: the queue and the player engine.
7. `PLAY-2`, `PLAY-3`: the now-playing bar and the player screen.
8. `PLAY-6`, `PLAY-7`: background audio, the lock screen and interruptions.
9. `TRANS-1`, `TRANS-2`, `TRANS-3`, `TRANS-4`, `TRANS-5`: the transcoding settings and stream URLs.
10. `TRANS-6`: quality in the player.
11. `LIB-6`, `SRV-6`, `SRV-7`: the settings sheet, re-authentication and sign out.
12. `ARCH-16`: confirm every Router and UseCase has tests.

## Verification backlog

Built requirements that are not fully verified. Clear these before starting new planned work.

- `TOOL-8`: push `main` from a terminal after a row becomes `done`, and check the hook offers the release, opens the notes in the editor and asks before pushing.
