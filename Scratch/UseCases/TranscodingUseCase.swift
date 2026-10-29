/// The transcoding settings (TRANS-1, TRANS-2, TRANS-3, TRANS-5).
protocol TranscodingUseCase {
    var settings: TranscodingSettings { get }

    func update(_ settings: TranscodingSettings)

    /// The quality for a track starting now, by the network the device is on.
    func qualityForNextTrack() -> StreamQuality
}

final class DefaultTranscodingUseCase: TranscodingUseCase {
    private let settingsGateway: SettingsGateway
    private let networkGateway: NetworkGateway
    private(set) var settings: TranscodingSettings

    init(settingsGateway: SettingsGateway, networkGateway: NetworkGateway) {
        self.settingsGateway = settingsGateway
        self.networkGateway = networkGateway
        settings = settingsGateway.transcoding() ?? .defaults
    }

    /// Saved at once. The track playing now keeps its quality; the next one uses this (TRANS-5).
    func update(_ settings: TranscodingSettings) {
        self.settings = settings
        settingsGateway.saveTranscoding(settings)
    }

    func qualityForNextTrack() -> StreamQuality {
        settings.quality(on: networkGateway.currentNetwork)
    }
}
