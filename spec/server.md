# Server connection

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `SRV-1` | With no saved server, the app opens on a setup screen asking for the server URL, username and password. | done | `AppRouterTests`, `AppRoutingUseCaseTests`, `SetupViewModelTests`; `manual:` launch on an erased simulator and see the setup screen with URL, username and password fields |
| `SRV-2` | The URL accepts `http` and `https`, an optional port, and an optional path prefix for a server behind a reverse proxy (e.g. `https://example.com/navidrome`). A URL without a scheme gets `https://`. | planned | `ServerURLTests` |
| `SRV-3` | **Connect** checks the server with `ping`. On success it saves the server and opens the library. On failure it stays on the setup screen and says why: server unreachable, wrong username or password, or not a Subsonic server. | planned | `ConnectUseCaseTests` |
| `SRV-4` | Requests use Subsonic token authentication (`t` = MD5 of password + salt, `s` = salt) with `c=Scratch`, `v=1.16.1` and `f=json`. The password is never sent and never stored: only the salt and token are kept. | planned | `SubsonicRequestTests` |
| `SRV-5` | The salt and token are stored in the Keychain; the URL and username in `UserDefaults`. On relaunch with a saved server the app opens the library directly. | planned | `CredentialGatewayTests`; `manual:` relaunch in the simulator |
| `SRV-6` | A request rejected as unauthorised (Subsonic error 40 or 41) after setup returns the user to the setup screen with the URL and username filled in. | planned | `AppRouterTests`, `LibraryUseCaseTests` |
| `SRV-7` | **Sign out** in settings stops playback, deletes the saved credentials and returns to the setup screen. | planned | `SignOutUseCaseTests` |

## Implementation notes

- Plain `http` is allowed to any host, because home servers are often reached by LAN address or over a VPN. That needs `NSAllowsArbitraryLoads` in `Info.plist`.
- A fixed salt and token pair is valid Subsonic auth: the server checks `md5(password + s) == t`. That is what lets `SRV-4` avoid keeping the password.
