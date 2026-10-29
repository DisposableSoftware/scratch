import Combine

/// The albums loaded so far. AlbumUseCase fills it; the Albums tab shows it.
final class AlbumsState: ObservableObject {
    @Published var albums: [Album] = []
    @Published var hasMoreAlbums = true
    /// How many albums the server has returned: the next page's offset, whatever is shown.
    @Published var nextOffset = 0
}
