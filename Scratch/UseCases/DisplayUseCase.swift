/// How the app is laid out: the albums per row (ALB-17, ALB-18).
protocol DisplayUseCase {
    /// What the screens show, and follow.
    var state: DisplayState { get }

    /// Sets the albums per row, within the allowed range, and saves it.
    func setAlbumsPerRow(_ count: Int)
}

final class DefaultDisplayUseCase: DisplayUseCase {
    private let settingsGateway: SettingsGateway
    let state: DisplayState

    init(settingsGateway: SettingsGateway, displayState: DisplayState) {
        self.settingsGateway = settingsGateway
        state = displayState
        state.albumsPerRow = AlbumsPerRow.clamped(settingsGateway.albumsPerRow() ?? AlbumsPerRow.default)
    }

    func setAlbumsPerRow(_ count: Int) {
        let count = AlbumsPerRow.clamped(count)
        state.albumsPerRow = count
        settingsGateway.saveAlbumsPerRow(count)
    }
}
