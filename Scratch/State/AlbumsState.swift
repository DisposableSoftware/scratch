import Combine

/// The albums loaded so far. AlbumUseCase fills it; the Albums tab shows it.
final class AlbumsState: ObservableObject {
    /// The albums the user has starred, by name (ALB-3).
    @Published var favourites: [Album] = []
    /// The other albums, a page at a time (ALB-4).
    @Published var albums: [Album] = []
    @Published var hasMoreAlbums = true
    /// How many albums the server has returned: the next page's offset, whatever is shown.
    @Published var nextOffset = 0
}
