/// Which of Catppuccin's four palettes the app uses (LOOK-1). Latte is light and the others are dark,
/// and the flavour sets the appearance with it (LOOK-4).
nonisolated enum Flavour: String, CaseIterable {
    case latte
    case frappe
    case macchiato
    case mocha

    static let `default` = Flavour.mocha

    var isDark: Bool { self != .latte }

    var label: String {
        switch self {
        case .latte: "Latte"
        case .frappe: "Frappé"
        case .macchiato: "Macchiato"
        case .mocha: "Mocha"
        }
    }
}
