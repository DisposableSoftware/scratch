/// Catppuccin's colours (https://catppuccin.com/palette), by the Catppuccin community and not ours
/// (LOOK-7). `design/catppuccin/*.css` holds the published values, and `PaletteTests` checks this
/// table against those files.
nonisolated enum Palette {
    /// The accent in the flavour, as 0xRRGGBB.
    static func hex(_ accent: Accent, in flavour: Flavour) -> UInt32 {
        accents(in: flavour)[accent] ?? 0
    }

    /// The flavour's red, which marks errors (LOOK-3).
    static func red(in flavour: Flavour) -> UInt32 {
        switch flavour {
        case .latte: 0xd20f39
        case .frappe: 0xe78284
        case .macchiato: 0xed8796
        case .mocha: 0xf38ba8
        }
    }

    private static func accents(in flavour: Flavour) -> [Accent: UInt32] {
        switch flavour {
        case .latte: [
            .rosewater: 0xdc8a78,
            .flamingo: 0xdd7878,
            .pink: 0xea76cb,
            .mauve: 0x8839ef,
            .maroon: 0xe64553,
            .peach: 0xfe640b,
            .yellow: 0xdf8e1d,
            .green: 0x40a02b,
            .teal: 0x179299,
            .sky: 0x04a5e5,
            .sapphire: 0x209fb5,
            .blue: 0x1e66f5,
            .lavender: 0x7287fd,
        ]

        case .frappe: [
            .rosewater: 0xf2d5cf,
            .flamingo: 0xeebebe,
            .pink: 0xf4b8e4,
            .mauve: 0xca9ee6,
            .maroon: 0xea999c,
            .peach: 0xef9f76,
            .yellow: 0xe5c890,
            .green: 0xa6d189,
            .teal: 0x81c8be,
            .sky: 0x99d1db,
            .sapphire: 0x85c1dc,
            .blue: 0x8caaee,
            .lavender: 0xbabbf1,
        ]

        case .macchiato: [
            .rosewater: 0xf4dbd6,
            .flamingo: 0xf0c6c6,
            .pink: 0xf5bde6,
            .mauve: 0xc6a0f6,
            .maroon: 0xee99a0,
            .peach: 0xf5a97f,
            .yellow: 0xeed49f,
            .green: 0xa6da95,
            .teal: 0x8bd5ca,
            .sky: 0x91d7e3,
            .sapphire: 0x7dc4e4,
            .blue: 0x8aadf4,
            .lavender: 0xb7bdf8,
        ]

        case .mocha: [
            .rosewater: 0xf5e0dc,
            .flamingo: 0xf2cdcd,
            .pink: 0xf5c2e7,
            .mauve: 0xcba6f7,
            .maroon: 0xeba0ac,
            .peach: 0xfab387,
            .yellow: 0xf9e2af,
            .green: 0xa6e3a1,
            .teal: 0x94e2d5,
            .sky: 0x89dceb,
            .sapphire: 0x74c7ec,
            .blue: 0x89b4fa,
            .lavender: 0xb4befe,
        ]
        }
    }
}
