import Combine

/// How the app looks, as the user set it. DisplayUseCase updates it; the grid and the root follow it.
final class DisplayState: ObservableObject {
    @Published var albumsPerRow = AlbumsPerRow.default
    @Published var flavour = Flavour.default
    @Published var accent = Accent.default
}
