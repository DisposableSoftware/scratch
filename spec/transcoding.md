# Transcoding

The server does the transcoding. Scratch chooses what to ask for on each `stream` request.

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `TRANS-1` | Settings offer a stream format: **Original** (the file as stored), **MP3** or **AAC**. | done | `TranscodingSettingsTests`, `SettingsViewModelTests`; the sheet itself is in the verification backlog |
| `TRANS-2` | For MP3 and AAC, settings offer a maximum bitrate: **Unlimited**, 320, 256, 192, 128, 96 or 64 kbps. Original is never capped: with it selected, the bitrate shows Unlimited and can't be changed. | done | `TranscodingSettingsTests`, `SettingsViewModelTests`, `StreamURLTests` |
| `TRANS-3` | Format and bitrate are set separately for Wi-Fi and for cellular, and a track uses the setting for the network it starts on. Defaults: Wi-Fi Original/Unlimited, cellular MP3/192 kbps. | done | `PlaybackUseCaseTests`, `TranscodingSettingsTests` |
| `TRANS-4` | The `stream` request carries `format` (`raw` for Original, else `mp3` or `aac`) and, for MP3 and AAC, `maxBitRate` (left out for Unlimited), plus `estimateContentLength=true`. | done | `StreamURLTests`; `manual:` `scripts/manual/live-connect.sh` checks the content type served for MP3 and AAC, and that each quality plays and seeks |
| `TRANS-5` | Settings persist across launches. A change applies from the next track; the current track keeps playing as it is. | done | `TranscodingSettingsTests`, `SettingsGatewayTests`, `PlaybackUseCaseTests` |
| `TRANS-6` | The player shows the quality requested for the current track, e.g. `MP3 · 192 kbps`, `AAC`, or `Original`. | done | `PlayerViewModelTests`, `PlaybackUseCaseTests`; `manual:` `scripts/manual/snapshots.sh` renders the player with its quality |

## Implementation notes

- Opus is left out on purpose. Navidrome serves Opus in an Ogg container, and AVFoundation can't play Ogg.
- Original can't carry a cap. Measured on Navidrome 0.64: `format=raw&maxBitRate=96` returns the untouched file, and leaving out `format` with a cap returns Ogg Opus, which AVFoundation can't play. So a cap needs MP3 or AAC, and the user picks which.
- `estimateContentLength=true` gives AVPlayer a content length for a transcoded stream, which it needs for duration and seeking. Checked against Navidrome 0.64: MP3 and AAC streams seek to a minute in. Without it, the fix would be a new request with `timeOffset`, which would need its own row.
- Whether a server has an AAC transcoding configured is up to its admin. An `AAC` request the server can't serve should surface as a `PLAY-8` error, not be swapped for something else silently.
- The network is read from `NWPathMonitor`'s current path when each track starts, so it's right from launch. Anything that isn't only cellular counts as Wi-Fi: wired, other networks, Wi-Fi Assist, and no network at all.
- Saved settings that can't be read fall back to the defaults. A saved Original with a cap, from before `TRANS-2` said Original is never capped, loads uncapped.
