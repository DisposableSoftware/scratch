/// How the app looks: the albums per row (ALB-17, ALB-18), and the flavour and accent (LOOK-6).
protocol DisplayUseCase {
    /// What the screens show, and follow.
    var state: DisplayState { get }

    /// Sets the albums per row, within the allowed range, and saves it.
    func setAlbumsPerRow(_ count: Int)

    /// Sets the flavour and saves it.
    func setFlavour(_ flavour: Flavour)

    /// Sets the accent and saves it.
    func setAccent(_ accent: Accent)
}

final class DefaultDisplayUseCase: DisplayUseCase {
    private let settingsGateway: SettingsGateway
    let state: DisplayState

    init(settingsGateway: SettingsGateway, displayState: DisplayState) {
        self.settingsGateway = settingsGateway
        state = displayState
        state.albumsPerRow = AlbumsPerRow.clamped(settingsGateway.albumsPerRow() ?? AlbumsPerRow.default)
        state.flavour = settingsGateway.flavour() ?? Flavour.default
        state.accent = settingsGateway.accent() ?? Accent.default
    }

    func setAlbumsPerRow(_ count: Int) {
        let count = AlbumsPerRow.clamped(count)
        state.albumsPerRow = count
        settingsGateway.saveAlbumsPerRow(count)
    }

    func setFlavour(_ flavour: Flavour) {
        state.flavour = flavour
        settingsGateway.saveFlavour(flavour)
    }

    func setAccent(_ accent: Accent) {
        state.accent = accent
        settingsGateway.saveAccent(accent)
    }
}
