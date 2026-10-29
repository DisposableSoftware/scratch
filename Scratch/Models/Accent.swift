/// The accent colours the user can pick (LOOK-5): Catppuccin's fourteen, without red, which the app
/// keeps for errors (LOOK-3).
nonisolated enum Accent: String, CaseIterable {
    case rosewater
    case flamingo
    case pink
    case mauve
    case maroon
    case peach
    case yellow
    case green
    case teal
    case sky
    case sapphire
    case blue
    case lavender

    static let `default` = Accent.mauve

    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}
