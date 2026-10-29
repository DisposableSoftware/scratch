import Foundation

/// The user's settings, kept between launches (TRANS-5).
protocol SettingsGateway {
    func transcoding() -> TranscodingSettings?
    func saveTranscoding(_ settings: TranscodingSettings)
}

final class UserDefaultsSettingsGateway: SettingsGateway {
    private static let transcodingKey = "settings.transcoding"
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
}
