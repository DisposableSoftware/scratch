import Foundation

/// The server's playlists (PLST-1, PLST-7).
protocol PlaylistUseCase {
    /// Every playlist, by name, or nil when signed out meanwhile.
    func playlists() async throws(ServerError) -> [Playlist]?

    /// One playlist with its tracks in its own order, or nil when signed out meanwhile.
    func playlist(id: Playlist.ID) async throws(ServerError) -> PlaylistDetail?
}

final class DefaultPlaylistUseCase: PlaylistUseCase {
    private let playlistGateway: PlaylistGateway
    private let sessionState: SessionState

    init(playlistGateway: PlaylistGateway, sessionState: SessionState) {
        self.playlistGateway = playlistGateway
        self.sessionState = sessionState
    }

    func playlists() async throws(ServerError) -> [Playlist]? {
        guard let server = sessionState.server else { return nil }

        let playlists: [Playlist]

        do {
            playlists = try await playlistGateway.playlists(server: server)
        } catch {
            // A failure for a server signed out of meanwhile doesn't matter any more, and mustn't
            // sign out whoever signed in since.
            guard sessionState.server == server else { return nil }

            throw error
        }

        guard sessionState.server == server else { return nil }

        // By name, with numbers read as numbers and case ignored, as the album favourites are.
        return playlists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func playlist(id: Playlist.ID) async throws(ServerError) -> PlaylistDetail? {
        guard let server = sessionState.server else { return nil }

        let detail: PlaylistDetail

        do {
            detail = try await playlistGateway.playlist(id: id, server: server)
        } catch {
            guard sessionState.server == server else { return nil }

            throw error
        }

        guard sessionState.server == server else { return nil }

        return detail
    }
}
