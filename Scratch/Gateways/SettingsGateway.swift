import Foundation

/// The user's settings, kept between launches (TRANS-5).
protocol SettingsGateway {
    func transcoding() -> TranscodingSettings?
    func saveTranscoding(_ settings: TranscodingSettings)

    func albumsPerRow() -> Int?
    func saveAlbumsPerRow(_ count: Int)

    func flavour() -> Flavour?
    func saveFlavour(_ flavour: Flavour)

    func accent() -> Accent?
    func saveAccent(_ accent: Accent)
}

final class UserDefaultsSettingsGateway: SettingsGateway {
    private static let transcodingKey = "settings.transcoding"
    private static let albumsPerRowKey = "settings.albumsPerRow"
    private static let flavourKey = "settings.flavour"
    private static let accentKey = "settings.accent"
    private let defaults: UserDefaults

    init(environment: AppEnvironment) {
        defaults = environment.defaults
    }

    func transcoding() -> TranscodingSettings? {
        defaults.data(forKey: Self.transcodingKey).flatMap { try? JSONDecoder().decode(TranscodingSettings.self, from: $0) }
    }

    func saveTranscoding(_ settings: TranscodingSettings) {
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.transcodingKey)
    }

    /// A saved number, or a numeric string, which is what a `-key value` launch argument arrives
    /// as. Anything else counts as nothing saved.
    func albumsPerRow() -> Int? {
        switch defaults.object(forKey: Self.albumsPerRowKey) {
        case let number as Int: number
        case let text as String: Int(text.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    func saveAlbumsPerRow(_ count: Int) {
        defaults.set(count, forKey: Self.albumsPerRowKey)
    }

    /// A saved name, which is also what a `-settings.flavour NAME` launch argument arrives as. A name
    /// the app doesn't know counts as nothing saved (LOOK-6).
    func flavour() -> Flavour? {
        defaults.string(forKey: Self.flavourKey).flatMap(Flavour.init(rawValue:))
    }

    func saveFlavour(_ flavour: Flavour) {
        defaults.set(flavour.rawValue, forKey: Self.flavourKey)
    }

    func accent() -> Accent? {
        defaults.string(forKey: Self.accentKey).flatMap(Accent.init(rawValue:))
    }

    func saveAccent(_ accent: Accent) {
        defaults.set(accent.rawValue, forKey: Self.accentKey)
    }
}
