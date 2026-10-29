import Foundation

/// The mixes of the Me tab, made on the device (MIX-1 to MIX-9).
protocol MixUseCase {
    var state: MixesState { get }

    /// Checks whether the model can be asked now, and tells the state (MIX-1).
    func refreshAvailability()

    /// Makes the mixes again. On the first making each mix lands in the state as it is ready; on a
    /// later one the old mixes stay until the new ones replace them (MIX-3, MIX-4). Throws what the
    /// server threw; a failing model only gives a mix its rule's own tracks (MIX-8).
    func makeMixes() async throws(ServerError)
}

final class DefaultMixUseCase: MixUseCase {
    /// Most tracks the model is shown, which a small context holds (MIX-5).
    static let shortlistSize = 60

    /// Most tracks in a mix (MIX-6).
    static let mixSize = 25

    /// Most albums read for Most played and for On this day (MIX-5).
    static let albumsRead = 10

    /// Most pages of albums scanned for a release date, so a huge library isn't read in full.
    static let maxScannedPages = 20

    private let albumGateway: AlbumGateway
    private let modelGateway: MixModelGateway
    private let sessionState: SessionState
    private let mixesState: MixesState
    private let now: () -> Date
    private let calendar: Calendar

    var state: MixesState { mixesState }

    init(albumGateway: AlbumGateway, modelGateway: MixModelGateway, sessionState: SessionState, mixesState: MixesState, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.albumGateway = albumGateway
        self.modelGateway = modelGateway
        self.sessionState = sessionState
        self.mixesState = mixesState
        self.now = now
        self.calendar = calendar
    }

    func refreshAvailability() {
        let available = modelGateway.isAvailable

        if mixesState.isModelAvailable != available { mixesState.isModelAvailable = available }
    }

    func makeMixes() async throws(ServerError) {
        guard let server = sessionState.server else { return }

        let showEachAsMade = mixesState.mixes.isEmpty
        var made: [Mix] = []

        for kind in MixKind.allCases {
            let shortlist: [Track]

            do {
                shortlist = try await self.shortlist(for: kind, server: server)
            } catch {
                // A failure for a server signed out of meanwhile doesn't matter any more, and
                // mustn't sign out whoever signed in since.
                guard sessionState.server == server else { return }

                throw error
            }

            guard sessionState.server == server else { return }
            guard !shortlist.isEmpty else { continue }

            let newMix = await mix(kind, from: shortlist)

            // The model can take seconds: a sign-out or a cancelled refresh meanwhile means these
            // mixes are not wanted any more, and mustn't land after the sign-out cleared them.
            guard sessionState.server == server, !Task.isCancelled else { return }

            made.append(newMix)
            if showEachAsMade { mixesState.mixes = made }
        }

        guard sessionState.server == server else { return }

        mixesState.mixes = made
    }

    // MARK: Shortlists (MIX-5)

    private func shortlist(for kind: MixKind, server: SavedServer) async throws(ServerError) -> [Track] {
        let tracks: [Track]

        switch kind {
        case .hearts:
            tracks = try await albumGateway.starredTracks(server: server)
        case .mostPlayed:
            let albums = try await albumGateway.frequentAlbums(count: Self.albumsRead, server: server)
            let played = try await loadTracks(of: albums, server: server).filter { ($0.playCount ?? 0) > 0 }

            tracks = played.enumerated()
                .sorted { ($1.element.playCount ?? 0, $0.offset) < ($0.element.playCount ?? 0, $1.offset) }
                .map(\.element)
        case .onThisDay:
            tracks = try await loadTracks(of: try await albumsReleasedToday(server: server), server: server)
        }

        return Array(tracks.prefix(Self.shortlistSize))
    }

    private func loadTracks(of albums: [Album], server: SavedServer) async throws(ServerError) -> [Track] {
        var tracks: [Track] = []

        for album in albums.prefix(Self.albumsRead) {
            tracks += try await albumGateway.album(id: album.id, server: server).tracks.map(\.track)
        }

        return tracks
    }

    /// Scans the albums a page at a time for the ones released on today's month and day.
    private func albumsReleasedToday(server: SavedServer) async throws(ServerError) -> [Album] {
        let today = calendar.dateComponents([.month, .day], from: now())
        var found: [Album] = []

        for page in 0..<Self.maxScannedPages {
            let albums = try await albumGateway.albums(offset: page * DefaultAlbumUseCase.pageSize, count: DefaultAlbumUseCase.pageSize, server: server)

            found += albums.filter { $0.releaseMonth == today.month && $0.releaseDay == today.day }
            if albums.count < DefaultAlbumUseCase.pageSize { break }
        }

        return found
    }

    // MARK: Asking the model (MIX-6 to MIX-8)

    private func mix(_ kind: MixKind, from shortlist: [Track]) async -> Mix {
        guard modelGateway.isAvailable,
              let curation = try? await modelGateway.curate(kind: kind, shortlist: shortlist, limit: Self.mixSize)
        else { return fallback(kind, shortlist) }

        // MIX-7: only positions in the shortlist, each once.
        var seen = Set<Int>()
        let tracks = curation.picks
            .filter { shortlist.indices.contains($0 - 1) && seen.insert($0).inserted }
            .prefix(Self.mixSize)
            .map { shortlist[$0 - 1] }

        guard !tracks.isEmpty else { return fallback(kind, shortlist) }

        let name = curation.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = curation.description.trimmingCharacters(in: .whitespacesAndNewlines)

        return Mix(kind: kind, name: name.isEmpty ? kind.defaultName : name, description: description.isEmpty ? kind.defaultDescription : description, tracks: Array(tracks))
    }

    private func fallback(_ kind: MixKind, _ shortlist: [Track]) -> Mix {
        Mix(kind: kind, name: kind.defaultName, description: kind.defaultDescription, tracks: Array(shortlist.prefix(Self.mixSize)))
    }
}
