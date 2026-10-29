import Foundation

/// The server's library.
protocol LibraryGateway {
    /// One page of every track, in the server's order.
    func tracks(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Track]
}

final class RemoteLibraryGateway: LibraryGateway {
    private let client: SubsonicClient

    init(networkSession: NetworkSession) {
        client = SubsonicClient(session: networkSession)
    }

    /// `search3` with an empty query lists every song, paged by songCount and songOffset.
    func tracks(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Track] {
        let request = SubsonicRequest(method: "search3", parameters: [
            URLQueryItem(name: "query", value: ""),
            URLQueryItem(name: "songCount", value: String(count)),
            URLQueryItem(name: "songOffset", value: String(offset)),
            URLQueryItem(name: "artistCount", value: "0"),
            URLQueryItem(name: "albumCount", value: "0"),
        ])
        let payload = try await client.send(request, to: server, as: SearchPayload.self)
        return (payload.searchResult3.song ?? []).map(\.track)
    }
}

private struct SearchPayload: Decodable {
    struct Result: Decodable {
        let song: [Song]?
    }

    struct Song: Decodable {
        let id: String
        let title: String?
        let artist: String?
        let album: String?
        let duration: Int?
        let coverArt: String?

        var track: Track {
            Track(id: id, title: title ?? "", artist: artist ?? "", album: album ?? "", duration: duration, coverArtID: coverArt)
        }
    }

    let searchResult3: Result
}
