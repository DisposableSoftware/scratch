import Combine

/// How the app is laid out, as the user set it. DisplayUseCase updates it; the grid follows it.
final class DisplayState: ObservableObject {
    @Published var albumsPerRow = AlbumsPerRow.default
}
