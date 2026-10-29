import Foundation

/// The server's albums.
protocol AlbumGateway {
    /// One page of every album, ordered by name.
    func albums(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Album]
}

final class RemoteAlbumGateway: AlbumGateway {
    private let client: SubsonicClient

    init(networkSession: NetworkSession) {
        client = SubsonicClient(session: networkSession)
    }

    /// `getAlbumList2` by name, paged by size and offset.
    func albums(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Album] {
        let request = SubsonicRequest(method: "getAlbumList2", parameters: [
            URLQueryItem(name: "type", value: "alphabeticalByName"),
            URLQueryItem(name: "size", value: String(count)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
        let payload = try await client.send(request, to: server, as: AlbumListPayload.self)
        return (payload.albumList2.album ?? []).map(\.album)
    }
}

private struct AlbumListPayload: Decodable {
    struct List: Decodable {
        let album: [AlbumEntry]?
    }

    let albumList2: List
}

/// An album as the server lists it. Every field but the ID is optional, as on the wire.
struct AlbumEntry: Decodable {
    let id: String
    let name: String?
    let artist: String?
    let displayArtist: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let year: Int?
    let genre: String?
    let starred: String?

    var album: Album {
        Album(
            id: id,
            name: name ?? "",
            artist: [displayArtist, artist].compactMap { $0 }.first { !$0.isEmpty } ?? "",
            coverArtID: coverArt.flatMap { $0.isEmpty ? nil : $0 },
            songCount: songCount,
            duration: duration,
            year: year,
            genre: genre,
            isStarred: starred != nil
        )
    }
}
