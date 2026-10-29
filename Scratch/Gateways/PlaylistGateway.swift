import Foundation

/// The server's playlists.
protocol PlaylistGateway {
    /// Every playlist the user can see, in the order the server gives.
    func playlists(server: SavedServer) async throws(ServerError) -> [Playlist]

    /// One playlist and its tracks, in the playlist's order.
    func playlist(id: Playlist.ID, server: SavedServer) async throws(ServerError) -> PlaylistDetail
}

final class RemotePlaylistGateway: PlaylistGateway {
    private let client: SubsonicClient

    init(networkSession: NetworkSession) {
        client = SubsonicClient(session: networkSession)
    }

    /// `getPlaylists` lists them all in one request.
    func playlists(server: SavedServer) async throws(ServerError) -> [Playlist] {
        let payload = try await client.send(SubsonicRequest(method: "getPlaylists"), to: server, as: PlaylistListPayload.self)

        return (payload.playlists.playlist ?? []).map(\.playlist)
    }

    /// `getPlaylist` returns the playlist with its tracks (`entry`) in one request.
    func playlist(id: Playlist.ID, server: SavedServer) async throws(ServerError) -> PlaylistDetail {
        let request = SubsonicRequest(method: "getPlaylist", parameters: [URLQueryItem(name: "id", value: id)])
        let payload = try await client.send(request, to: server, as: PlaylistDetailPayload.self).playlist

        return PlaylistDetail(playlist: payload.entry.playlist, tracks: (payload.songs ?? []).map(\.albumTrack.track))
    }
}

private struct PlaylistListPayload: Decodable {
    struct List: Decodable {
        let playlist: [PlaylistEntry]?
    }

    let playlists: List
}

private struct PlaylistDetailPayload: Decodable {
    /// The playlist's own fields, then the tracks `getPlaylist` adds.
    struct Detail: Decodable {
        let entry: PlaylistEntry
        let songs: [SongEntry]?

        init(from decoder: Decoder) throws {
            entry = try PlaylistEntry(from: decoder)
            songs = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent([SongEntry].self, forKey: .entry)
        }

        enum CodingKeys: String, CodingKey {
            case entry
        }
    }

    let playlist: Detail
}

/// A playlist as the server lists it. Every field but the ID is optional, as on the wire.
private struct PlaylistEntry: Decodable {
    let id: String
    let name: String?
    let owner: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?

    var playlist: Playlist {
        Playlist(
            id: id,
            name: name ?? "",
            owner: owner.flatMap { $0.isEmpty ? nil : $0 },
            coverArtID: coverArt.flatMap { $0.isEmpty ? nil : $0 },
            songCount: songCount,
            duration: duration
        )
    }
}
