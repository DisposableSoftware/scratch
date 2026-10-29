# Server connection

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `SRV-1` | With no saved server, the app opens on a setup screen asking for the server URL, username and password. | done | `AppRouterTests`, `AppRoutingUseCaseTests`, `SetupViewModelTests`; `manual:` launch on an erased simulator and see the setup screen with URL, username and password fields |
| `SRV-2` | The URL accepts `http` and `https`, an optional port, and an optional path prefix for a server behind a reverse proxy (e.g. `https://example.com/navidrome`). A URL without a scheme gets `https://`. | done | `ServerURLTests` |
| `SRV-3` | **Connect** checks the server with `ping`. On success it saves the server and opens the library. On failure it stays on the setup screen and says why: server unreachable, wrong username or password, or not a Subsonic server. | done | `ConnectUseCaseTests`, `ServerGatewayTests`, `SetupViewModelTests`, `AppRouterTests`; `manual:` `scripts/manual/live-connect.sh` against a real server (wrong password, a web page, a closed port, then the right credentials) |
| `SRV-4` | Requests use Subsonic token authentication (`t` = MD5 of password + salt, `s` = salt) with `c=Scratch`, `v=1.16.1` and `f=json`. The password is never sent and never stored: only the salt and token are kept. | done | `SubsonicRequestTests` (salt and token only; storage is checked with `SRV-5`) |
| `SRV-5` | The salt and token are stored in the Keychain; the URL and username in `UserDefaults`. On relaunch with a saved server the app opens the library directly. | done | `CredentialGatewayTests`, `SessionUseCaseTests`; `manual:` `scripts/manual/live-connect.sh` relaunches the app and screenshots the library |
| `SRV-6` | A request rejected as unauthorised (Subsonic error 40 or 41) after setup returns the user to the setup screen with the URL and username filled in. | partial: only library and album requests send the user back to setup; a rejected stream shows as a `PLAY-8` failure, and rejected cover art is just missing | `LibraryViewModelTests`, `SessionUseCaseTests`, `SetupViewModelTests`, `ServerErrorTests`, `AppRouterTests`; `manual:` live test: a request signed with stale credentials is rejected, `AlbumsViewModelTests`, `AlbumViewModelTests` |
| `SRV-7` | **Sign out** in settings stops playback, deletes the saved credentials and returns to the setup screen. | done | `SessionUseCaseTests`, `SettingsViewModelTests`, `PlaybackUseCaseTests`; the sheet itself is in the verification backlog |

## Implementation notes

- Plain `http` is allowed to any host, because home servers are often reached by LAN address or over a VPN. That needs `NSAllowsArbitraryLoads` in `Info.plist`.
- Every request carries a replayable token, so redirects are followed only within the same scheme, host and port. A redirect to a single-sign-on page, another host or plain http isn't followed, and reads as "not a Subsonic server".
- A 502, 503 or 504 page from a reverse proxy means the server behind it is down, so it reads as unreachable rather than "not a Subsonic server".
- The salt and token are one Keychain item, `AfterFirstUnlockThisDeviceOnly` and not synced, so background playback can sign requests with the screen locked. Deleting forgets the `UserDefaults` keys even if the Keychain refuses to delete its item, so a sign out always holds: without the URL and username nothing loads, and a leftover salt and token are no use alone.
- `+` in a query value is sent as `%2B`. Navidrome decodes `+` as a space, so a username containing `+` would otherwise never authenticate.
- A mistyped scheme (`http:/host`, `https//host`) is rejected, not read as a host name.
- A fixed salt and token pair is valid Subsonic auth: the server checks `md5(password + s) == t`. That is what lets `SRV-4` avoid keeping the password.
- After a rejection the account to fill in is held in memory, not saved: setup comes back empty if the app is quit on it. The setup screen says the server stopped accepting the saved sign-in. Error 41 means the server doesn't take token authentication at all, so signing in again fails the same way, with the server's own message.
- A library page, or its failure, for a server the app has signed out of since is dropped, so a late rejection can't sign out a session set up afterwards. A rejection while already signed out does nothing.
- Signing out keeps the transcoding settings and the session's cover-art cache. The cache is keyed by server URL, and cover art doesn't depend on who's asking.
