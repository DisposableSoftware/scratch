/// The albums: loading them from the start and a page at a time (ALB-4).
protocol AlbumUseCase {
    var albums: [Album] { get }
    var hasMoreAlbums: Bool { get }

    /// Loads the first page, replacing whatever was loaded.
    func loadFirstPage() async throws(ServerError)
    /// Loads the page after the last one, unless the server has run out or a load is running.
    func loadNextPage() async throws(ServerError)
}

final class DefaultAlbumUseCase: AlbumUseCase {
    static let pageSize = 100

    private let albumGateway: AlbumGateway
    private let sessionState: SessionState
    private let albumsState: AlbumsState
    private var loadingNextPage = false
    private var loadingFirstPage = false
    /// Bumped by every first-page load, so a page that arrives after a reload is dropped.
    private var generation = 0

    init(albumGateway: AlbumGateway, sessionState: SessionState, albumsState: AlbumsState) {
        self.albumGateway = albumGateway
        self.sessionState = sessionState
        self.albumsState = albumsState
    }

    var albums: [Album] { albumsState.albums }
    var hasMoreAlbums: Bool { albumsState.hasMoreAlbums }

    func loadFirstPage() async throws(ServerError) {
        guard let server = sessionState.server else { return }
        generation += 1
        let current = generation
        loadingFirstPage = true
        defer { if current == generation { loadingFirstPage = false } }
        let page: [Album]
        do {
            page = try await albumGateway.albums(offset: 0, count: Self.pageSize, server: server)
        } catch {
            guard current == generation, sessionState.server == server else { return }
            throw error
        }
        // A page for a server signed out of meanwhile, or from before a reload, is dropped.
        guard current == generation, sessionState.server == server else { return }
        var seen = Set<Album.ID>()
        albumsState.albums = page.filter { seen.insert($0.id).inserted }
        albumsState.hasMoreAlbums = page.count == Self.pageSize
        albumsState.nextOffset = page.count
    }

    func loadNextPage() async throws(ServerError) {
        // While a reload runs, the offset would be the old list's: wait for the new one.
        guard let server = sessionState.server, albumsState.hasMoreAlbums, !loadingNextPage, !loadingFirstPage else { return }
        loadingNextPage = true
        defer { loadingNextPage = false }
        let current = generation
        let page: [Album]
        do {
            page = try await albumGateway.albums(offset: albumsState.nextOffset, count: Self.pageSize, server: server)
        } catch {
            guard current == generation, sessionState.server == server else { return }
            throw error
        }
        guard current == generation, sessionState.server == server else { return }
        // If the server's order shifted between pages, an album can come round again.
        let known = Set(albumsState.albums.map(\.id))
        albumsState.albums += page.filter { !known.contains($0.id) }
        albumsState.hasMoreAlbums = page.count == Self.pageSize
        albumsState.nextOffset += page.count
    }
}
