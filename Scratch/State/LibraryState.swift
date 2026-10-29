import Combine

/// The tracks loaded so far. LibraryUseCase fills it; playback will queue from it.
final class LibraryState: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var hasMoreTracks = true
}
