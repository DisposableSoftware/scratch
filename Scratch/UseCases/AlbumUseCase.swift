import Foundation

/// The albums: the favourites, and the others a page at a time (ALB-3, ALB-4).
protocol AlbumUseCase {
    /// The starred albums, by name.
    var favourites: [Album] { get }
    /// The other albums, in the server's order.
    var albums: [Album] { get }
    var hasMoreAlbums: Bool { get }

    /// Loads the favourites and the first page, replacing whatever was loaded. Both must load.
    func loadFirstPage() async throws(ServerError)
    /// Loads the page after the last one, unless the server has run out or a load is running.
    func loadNextPage() async throws(ServerError)
    /// One album with its tracks in disc and track order, or nil when signed out meanwhile.
    func album(id: Album.ID) async throws(ServerError) -> AlbumDetail?
}

final class DefaultAlbumUseCase: AlbumUseCase {
    static let pageSize = 100
    /// Most pages taken in a row to find an album that isn't a favourite, so a server that ignores
    /// the offset can't keep a load running for good.
    static let maxGapPages = 10

    private let albumGateway: AlbumGateway
    private let sessionState: SessionState
    private let albumsState: AlbumsState
    /// The generation a next-page load belongs to, while one is out. A page left over from before
    /// a reload doesn't stop the new list loading its own.
    private var loadingNextPageFor: Int?
    private var loadingFirstPage = false
    /// Bumped by every first-page load, so a page that arrives after a reload is dropped.
    private var generation = 0

    init(albumGateway: AlbumGateway, sessionState: SessionState, albumsState: AlbumsState) {
        self.albumGateway = albumGateway
        self.sessionState = sessionState
        self.albumsState = albumsState
    }

    var favourites: [Album] { albumsState.favourites }
    var albums: [Album] { albumsState.albums }
    var hasMoreAlbums: Bool { albumsState.hasMoreAlbums }

    func loadFirstPage() async throws(ServerError) {
        guard let server = sessionState.server else { return }
        generation += 1
        let current = generation
        loadingFirstPage = true
        defer { if current == generation { loadingFirstPage = false } }

        // The favourites and the first page load together.
        let gateway = albumGateway
        let starredTask = Task { () async -> Result<[Album], ServerError> in
            do throws(ServerError) {
                return .success(try await gateway.starredAlbums(server: server))
            } catch {
                return .failure(error)
            }
        }
        let page: [Album]
        let starred: [Album]
        do {
            page = try await albumGateway.albums(offset: 0, count: Self.pageSize, server: server)
            starred = try await starredTask.value.get()
        } catch {
            starredTask.cancel()
            guard current == generation, sessionState.server == server else { return }
            throw error
        }
        // A page for a server signed out of meanwhile, or from before a reload, is dropped.
        guard current == generation, sessionState.server == server else { return }

        let favourites = Self.byName(starred)
        let favouriteIDs = Set(favourites.map(\.id))
        var seen = Set<Album.ID>()
        albumsState.favourites = favourites
        albumsState.albums = page.filter { !favouriteIDs.contains($0.id) && seen.insert($0.id).inserted }
        albumsState.hasMoreAlbums = page.count == Self.pageSize
        albumsState.nextOffset = page.count

        // A page of nothing but favourites shows nothing new, so nothing would ask for the next.
        var gapPages = 0
        while albumsState.albums.isEmpty, albumsState.hasMoreAlbums, gapPages < Self.maxGapPages {
            gapPages += 1
            guard try await appendNextPage(server: server, generation: current) != nil else { return }
        }
    }

    func loadNextPage() async throws(ServerError) {
        // While a reload runs, the offset would be the old list's: wait for the new one.
        guard let server = sessionState.server, albumsState.hasMoreAlbums, loadingNextPageFor != generation, !loadingFirstPage else { return }
        let current = generation
        loadingNextPageFor = current
        defer { if loadingNextPageFor == current { loadingNextPageFor = nil } }
        for _ in 0..<Self.maxGapPages {
            guard let added = try await appendNextPage(server: server, generation: current) else { return }
            // A page of nothing but favourites adds nothing to scroll to, so take the next too.
            if added > 0 || !albumsState.hasMoreAlbums { return }
        }
    }

    func album(id: Album.ID) async throws(ServerError) -> AlbumDetail? {
        guard let server = sessionState.server else { return nil }
        var detail: AlbumDetail
        do {
            detail = try await albumGateway.album(id: id, server: server)
        } catch {
            // A failure for a server signed out of meanwhile doesn't matter any more, and mustn't
            // sign out whoever signed in since.
            guard sessionState.server == server else { return nil }
            throw error
        }
        // The server's order, but by disc and track number; a track with no number keeps its place
        // after the numbered ones, and ties keep the server's order.
        detail.tracks = detail.tracks.enumerated()
            .sorted { ($0.element.disc, $0.element.number ?? Int.max, $0.offset) < ($1.element.disc, $1.element.number ?? Int.max, $1.offset) }
            .map(\.element)
        guard sessionState.server == server else { return nil }
        return detail
    }

    /// Fetches the page after the last and adds what isn't a favourite or already shown. Returns
    /// how many it added, or nil if the page is for a reload or a server since left, and dropped.
    private func appendNextPage(server: SavedServer, generation current: Int) async throws(ServerError) -> Int? {
        let page: [Album]
        do {
            page = try await albumGateway.albums(offset: albumsState.nextOffset, count: Self.pageSize, server: server)
        } catch {
            guard current == generation, sessionState.server == server else { return nil }
            throw error
        }
        guard current == generation, sessionState.server == server else { return nil }
        // If the server's order shifted between pages, an album can come round again.
        var known = Set(albumsState.albums.map(\.id)).union(albumsState.favourites.map(\.id))
        let added = page.filter { known.insert($0.id).inserted }
        albumsState.albums += added
        albumsState.hasMoreAlbums = page.count == Self.pageSize
        albumsState.nextOffset += page.count
        return added.count
    }

    private static func byName(_ albums: [Album]) -> [Album] {
        var seen = Set<Album.ID>()
        return albums.filter { seen.insert($0.id).inserted }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }
}
