# Transcoding

The server does the transcoding. Scratch chooses what to ask for on each `stream` request.

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `TRANS-1` | Settings offer a stream format: **Original** (the file as stored), **MP3** or **AAC**. | planned | `TranscodingSettingsTests` |
| `TRANS-2` | For MP3 and AAC, settings offer a maximum bitrate: **Unlimited**, 320, 256, 192, 128, 96 or 64 kbps. Original is never capped: with it selected, the bitrate shows Unlimited and can't be changed. | planned | `TranscodingSettingsTests` |
| `TRANS-3` | Format and bitrate are set separately for Wi-Fi and for cellular, and a track uses the setting for the network it starts on. Defaults: Wi-Fi Original/Unlimited, cellular MP3/192 kbps. | planned | `StreamURLTests`, `TranscodingSettingsTests` |
| `TRANS-4` | The `stream` request carries `format` (`raw` for Original, else `mp3` or `aac`) and, for MP3 and AAC, `maxBitRate` (left out for Unlimited), plus `estimateContentLength=true`. | planned | `StreamURLTests` |
| `TRANS-5` | Settings persist across launches. A change applies from the next track; the current track keeps playing as it is. | planned | `TranscodingSettingsTests` |
| `TRANS-6` | The player shows the quality requested for the current track, e.g. `MP3 · 192 kbps`, `AAC`, or `Original`. | planned | `PlayerViewModelTests` |

## Implementation notes

- Opus is left out on purpose. Navidrome serves Opus in an Ogg container, and AVFoundation can't play Ogg.
- Original can't carry a cap. Measured on Navidrome 0.64: `format=raw&maxBitRate=96` returns the untouched file, and leaving out `format` with a cap returns Ogg Opus, which AVFoundation can't play. So a cap needs MP3 or AAC, and the user picks which.
- `estimateContentLength=true` gives AVPlayer a content length for a transcoded stream, which it needs for duration and seeking. Check seeking in a transcoded stream against a real server. If AVPlayer can't seek in it, the fix is a new request with `timeOffset`, and that needs its own row.
- Whether a server has an AAC transcoding configured is up to its admin. An `AAC` request the server can't serve should surface as a `PLAY-8` error, not be swapped for something else silently.
