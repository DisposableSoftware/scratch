/// The track list: loading it from the start and a page at a time (LIB-2).
protocol LibraryUseCase {
    var tracks: [Track] { get }
    var hasMoreTracks: Bool { get }

    /// Loads the first page, replacing whatever was loaded.
    func loadFirstPage() async throws(ServerError)
    /// Loads the page after the last one, unless the server has run out or a load is running.
    func loadNextPage() async throws(ServerError)
}

final class DefaultLibraryUseCase: LibraryUseCase {
    static let pageSize = 100

    private let libraryGateway: LibraryGateway
    private let sessionState: SessionState
    private let libraryState: LibraryState
    private var loadingNextPage = false
    /// Bumped by every first-page load, so a page that arrives after a reload is dropped.
    private var generation = 0

    init(libraryGateway: LibraryGateway, sessionState: SessionState, libraryState: LibraryState) {
        self.libraryGateway = libraryGateway
        self.sessionState = sessionState
        self.libraryState = libraryState
    }

    var tracks: [Track] { libraryState.tracks }
    var hasMoreTracks: Bool { libraryState.hasMoreTracks }

    func loadFirstPage() async throws(ServerError) {
        guard let server = sessionState.server else { return }
        generation += 1
        let current = generation
        let page = try await libraryGateway.tracks(offset: 0, count: Self.pageSize, server: server)
        guard current == generation else { return }
        var seen = Set<Track.ID>()
        libraryState.tracks = page.filter { seen.insert($0.id).inserted }
        libraryState.hasMoreTracks = page.count == Self.pageSize
    }

    func loadNextPage() async throws(ServerError) {
        guard let server = sessionState.server, libraryState.hasMoreTracks, !loadingNextPage else { return }
        loadingNextPage = true
        defer { loadingNextPage = false }
        let current = generation
        let page = try await libraryGateway.tracks(offset: libraryState.tracks.count, count: Self.pageSize, server: server)
        guard current == generation else { return }
        // If the server's order shifted between pages, a track can come round again.
        let known = Set(libraryState.tracks.map(\.id))
        libraryState.tracks += page.filter { !known.contains($0.id) }
        libraryState.hasMoreTracks = page.count == Self.pageSize
    }
}
