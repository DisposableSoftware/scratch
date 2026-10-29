# Appearance

How Scratch looks: its colours and its icon. They follow the [DisposableSoftware style guide](https://github.com/DisposableSoftware/style-guide), as far as an iOS app can. The guide is written for the GTK desktop apps (a translucent window, no chrome, Catppuccin everywhere), and the parts that need a desktop don't apply here: Scratch keeps the system's backgrounds, text, fonts and tab bar, and takes only the **accent** and **error** colours, the **flavour** choice and the **icon** from the guide.

The palette is [Catppuccin](https://catppuccin.com), made by the Catppuccin community. It isn't ours.

## Colours

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `LOOK-1` | The app's colours come from the Catppuccin palette, in one of four flavours: Latte, Frappé, Macchiato or Mocha. The default is Mocha with the Mauve accent. | planned | `ThemeTests` (every flavour's accent and red equal the palette's published values) |
| `LOOK-2` | Controls, the selected tab, links, the progress of the scrubber, and the current track's marker take the chosen accent in the chosen flavour. | planned | `ThemeTests`, `DisplayUseCaseTests`; `manual:` `scripts/manual/live-connect.sh` screenshots the app in each flavour |
| `LOOK-3` | Error text and the player's failed state use the chosen flavour's red. | planned | `ThemeTests`; `manual:` the screenshots show a failed state in red |
| `LOOK-4` | The flavour sets the appearance: Frappé, Macchiato and Mocha are dark and Latte is light, whatever the system's light or dark setting says. Backgrounds and text stay the system's for that appearance. | planned | `ThemeTests`, `DisplayUseCaseTests`; `manual:` the screenshots show Latte light and Mocha dark with the simulator in the other mode |
| `LOOK-5` | Settings has an **Appearance** section with a **Flavour** choice (Latte, Frappé, Macchiato, Mocha) and an **Accent** choice of the palette's 14 accent colours. | planned | `SettingsViewModelTests`; `manual:` open settings and check both choices, with each accent shown in its colour |
| `LOOK-6` | The choices are saved across launches and apply at once, without a restart. A saved flavour or accent the app doesn't know counts as nothing saved and gives Mocha or Mauve. | planned | `SettingsGatewayTests`, `DisplayUseCaseTests`; changing them from the sheet is in the verification backlog |
| `LOOK-7` | The README credits Catppuccin with links to catppuccin.com, and the file holding the palette says in its header where the values come from. | planned | `manual:` read the README and the header of the palette file |

## Icon

| ID | Requirement | Status | Verified by |
|----|-------------|--------|-------------|
| `LOOK-8` | The app icon is flat and in Catppuccin Mocha: a dark vinyl record with a Mauve label and one light scratch across it. It has no gradient, no text and no fine detail, fills the whole square, and stays readable at small sizes. It doesn't change with the flavour. | planned | `manual:` install on the simulator and check the Home Screen icon and its small sizes (Spotlight, Settings); the build shows no asset catalog warning |

## Implementation notes

- The guide has no iOS page, and `cmx` (macOS) is its one exception that uses system colours. Scratch does the same for backgrounds and text. Nothing here adds the guide's transparent window, `flavor = gtk`, user stylesheet or keybinding rules.
- Dark flavours with the system's own light background would make the pale accents hard to read, which is why `LOOK-4` fixes the appearance with the flavour. The flavour is the user's choice and never switches with the system, as in the guide.
- The accent is not checked for contrast. Some of Latte's accents (Yellow, Rosewater, Flamingo) are weak on white. The user picks the accent, so the app shows it as it is.
- Take the hex values from the guide's `reference/themes/*.css`, keeping the header `Catppuccin <flavour> - https://catppuccin.com/palette` for each flavour. Views name palette roles and never write a colour. The `AccentColor` asset keeps Mocha's Mauve, so anything drawn before the root view applies the choice matches the default.
- The flavour and accent are saved with the other settings, in the display state next to the albums per row. `-settings.flavour NAME` and `-settings.accent NAME` launch arguments stand in for them, as `-settings.albumsPerRow` does, so the screenshots can show every flavour.
- The icon is a single 1024×1024 PNG without transparency, which iOS rounds itself. Keep its source SVG in the repo (`design/AppIcon.svg`) so it can be redrawn, in the style of the guide's `assets/icons/*.svg`.
- The guide has no iOS page and its recipes are GTK. Once this is built, `docs/known-gaps.md` there should say Scratch is the second app to use system colours, and its icon page should note that iOS icons are full squares.
