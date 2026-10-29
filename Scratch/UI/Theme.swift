import SwiftUI

/// The colours the screens take from Catppuccin (LOOK-1 to LOOK-4), for the flavour and accent the
/// user chose. Backgrounds and text stay the system's.
struct Theme: Equatable {
    let accent: Color

    /// The colour for text on a filled accent: dark or light, whichever reads (LOOK-9).
    let onAccent: Color
    let error: Color
    let colorScheme: ColorScheme

    static let standard = Theme(flavour: .default, accent: .default)

    init(flavour: Flavour, accent: Accent) {
        self.accent = Color(accent, in: flavour)
        onAccent = Color(hex: Contrast.label(on: Palette.hex(accent, in: flavour)))
        error = Color(hex: Palette.red(in: flavour))
        colorScheme = flavour.isDark ? .dark : .light
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }

    /// An accent as the flavour draws it.
    init(_ accent: Accent, in flavour: Flavour) {
        self.init(hex: Palette.hex(accent, in: flavour))
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.standard
}

extension EnvironmentValues {
    /// The theme the root view sets, for the colours the system doesn't supply.
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
