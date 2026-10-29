# Appearance

How Scratch looks: its colours and its icon. They follow the [DisposableSoftware style guide](https://github.com/DisposableSoftware/style-guide), as far as an iOS app can. The guide is written for the GTK desktop apps (a translucent window, no chrome, Catppuccin everywhere), and the parts that need a desktop don't apply here: Scratch keeps the system's backgrounds, text, fonts and tab bar, and takes only the **accent** and **error** colours, the **flavour** choice and the **icon** from the guide.

The palette is [Catppuccin](https://catppuccin.com), made by the Catppuccin community. It isn't ours.

## Colours

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `LOOK-1` | The app's colours come from the Catppuccin palette, in one of four flavours: Latte, Frappé, Macchiato or Mocha. The default is Mocha with the Mauve accent. | done | `PaletteTests` (every flavour's accents and red equal `design/catppuccin/*.css`, copies of the published palette; Mocha with Mauve is the default) |
| `LOOK-2` | Buttons, pickers, the selected tab and the scrubber take the chosen accent in the chosen flavour. The player's previous, play/pause and next glyphs stay the primary text colour. | done | `PaletteTests`, `SettingsViewModelTests`; `manual:` `scripts/manual/live-connect.sh` screenshots the real app in each flavour with an accent (`look-*-albums.png`), and `scripts/manual/snapshots.sh` the settings sheet and the player in each (`look-*-settings.png`) |
| `LOOK-3` | Error text and the player's failed state use the chosen flavour's red. | done | `PaletteTests`; `manual:` `scripts/manual/snapshots.sh` renders the failed player in each flavour's red (`look-*-player-failed.png`) |
| `LOOK-4` | The flavour sets the appearance: Frappé, Macchiato and Mocha are dark and Latte is light, whatever the system's light or dark setting says. Backgrounds and text stay the system's for that appearance. | done | `PaletteTests` (only Latte is light); `manual:` the live screenshots show Latte light and Macchiato dark in the same simulator |
| `LOOK-5` | Settings has an **Appearance** section with a **Flavour** choice (Latte, Frappé, Macchiato, Mocha) and an **Accent** choice of the palette's accent colours, without red, which is kept for errors. | done | `SettingsViewModelTests`; `manual:` `scripts/manual/snapshots.sh` renders the sheet with the Flavour choice and the 13 accents in their colours; tapping them is in the verification backlog |
| `LOOK-6` | The choices are saved across launches and apply at once, without a restart. A saved flavour or accent the app doesn't know counts as nothing saved and gives Mocha or Mauve. | done | `SettingsGatewayTests`, `DisplayUseCaseTests`, `SettingsViewModelTests`; the live screenshots read the saved choice at launch; changing it from the sheet is in the verification backlog |
| `LOOK-7` | The README credits Catppuccin with links to catppuccin.com, and the file holding the palette says in its header where the values come from. | done | `manual:` the README's Credits section links Catppuccin, its organisation and the palette; `design/catppuccin/*.css` keep their `Catppuccin <flavour> - https://catppuccin.com/palette` headers; `Palette.swift` says where its values come from |
| `LOOK-9` | The label of the filled **Play** button is readable on the accent: its contrast with the button is at least 4.5:1 in every flavour and with every accent. | done | `PaletteTests` (the label chosen for each of the 52 accents has a ratio of at least 4.5:1, by arithmetic), `AlbumLayoutTests` (draws the real album screen in each of the 4 flavours × 13 accents and measures the label against the button; before the fix 50 of the 52 were under 4.5:1) |

## Icon

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `LOOK-8` | The app icon is flat and in Catppuccin Mocha: a dark vinyl record with a Mauve label and one light scratch across it. It has no gradient, no text and no fine detail, fills the whole square, and stays readable at small sizes. It doesn't change with the flavour. | done | `manual:` `design/render-icon.sh` renders `design/AppIcon.svg` to the 1024×1024 icon without an alpha channel; installed on the simulator it shows on the Home Screen at its real size with the label and the scratch readable, and the build shows no asset catalog warning |

## Implementation notes

- The guide has no iOS page, and `cmx` (macOS) is its one exception that uses system colours. Scratch does the same for backgrounds and text. Nothing here adds the guide's transparent window, `flavor = gtk`, user stylesheet or keybinding rules.
- Dark flavours with the system's own light background would make the pale accents hard to read, which is why `LOOK-4` fixes the appearance with the flavour. The flavour is the user's choice and never switches with the system, as in the guide.
- The accent itself is not checked for contrast against the screen's background (`LOOK-9` covers only text drawn on top of it). Some of Latte's accents (Yellow, Rosewater, Flamingo) are weak on white. The user picks the accent, so the app shows it as it is.
- The label on a filled accent is Mocha's crust (`#11111b`) or white, whichever has the higher contrast with the accent (`Contrast.label(on:)`, `Theme.onAccent`). The palette's own text colours can't reach 4.5:1 on all of Latte's accents, so white stands in for the light one. Any new filled-accent control takes its label colour from `theme.onAccent`.
- Take the hex values from the guide's `reference/themes/*.css`, keeping the header `Catppuccin <flavour> - https://catppuccin.com/palette` for each flavour. Views name palette roles and never write a colour. The `AccentColor` asset keeps Mocha's Mauve, so anything drawn before the root view applies the choice matches the default.
- The flavour and accent are saved with the other settings, in the display state next to the albums per row. `-settings.flavour NAME` and `-settings.accent NAME` launch arguments stand in for them, as `-settings.albumsPerRow` does, so the screenshots can show every flavour.
- The icon is a single 1024×1024 PNG without transparency, which iOS rounds itself. Keep its source SVG in the repo (`design/AppIcon.svg`) so it can be redrawn, in the style of the guide's `assets/icons/*.svg`.
- The guide has no iOS page and its recipes are GTK. Once this is built, `docs/known-gaps.md` there should say Scratch is the second app to use system colours, and its icon page should note that iOS icons are full squares.
