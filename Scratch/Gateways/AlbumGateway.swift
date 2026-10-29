import Foundation

/// The server's albums.
protocol AlbumGateway {
    /// One page of every album, ordered by name.
    func albums(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Album]

    /// Every album the user has starred, in the order the server gives.
    func starredAlbums(server: SavedServer) async throws(ServerError) -> [Album]

    /// One album and its tracks, in the order the server gives.
    func album(id: Album.ID, server: SavedServer) async throws(ServerError) -> AlbumDetail
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

    /// `getAlbum` returns the album with all its tracks in one request.
    func album(id: Album.ID, server: SavedServer) async throws(ServerError) -> AlbumDetail {
        let request = SubsonicRequest(method: "getAlbum", parameters: [URLQueryItem(name: "id", value: id)])
        let payload = try await client.send(request, to: server, as: AlbumDetailPayload.self).album
        var titles: [Int: String] = [:]

        for entry in payload.discTitles ?? [] where !(entry.title ?? "").isEmpty {
            titles[entry.disc] = entry.title
        }

        return AlbumDetail(
            album: payload.entry.album,
            tracks: (payload.song ?? []).map(\.albumTrack),
            discTitles: titles
        )
    }

    /// `getStarred2` lists the starred albums in one request.
    func starredAlbums(server: SavedServer) async throws(ServerError) -> [Album] {
        let payload = try await client.send(SubsonicRequest(method: "getStarred2"), to: server, as: StarredPayload.self)
        return (payload.starred2.album ?? []).map(\.album)
    }
}

private struct AlbumDetailPayload: Decodable {
    struct DiscTitle: Decodable {
        let disc: Int
        let title: String?
    }

    /// The album's own fields, then what only `getAlbum` adds.
    struct Detail: Decodable {
        let entry: AlbumEntry
        let discTitles: [DiscTitle]?
        let song: [SongEntry]?

        init(from decoder: Decoder) throws {
            entry = try AlbumEntry(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            discTitles = try container.decodeIfPresent([DiscTitle].self, forKey: .discTitles)
            song = try container.decodeIfPresent([SongEntry].self, forKey: .song)
        }

        enum CodingKeys: String, CodingKey {
            case discTitles, song
        }
    }

    let album: Detail
}

/// A track as `getAlbum` lists it.
struct SongEntry: Decodable {
    let id: String
    let title: String?
    let artist: String?
    let displayArtist: String?
    let album: String?
    let duration: Int?
    let coverArt: String?
    let track: Int?
    let discNumber: Int?

    var albumTrack: AlbumTrack {
        AlbumTrack(
            track: Track(
                id: id,
                title: title ?? "",
                artist: [displayArtist, artist].compactMap { $0 }.first { !$0.isEmpty } ?? "",
                album: album ?? "",
                duration: duration,
                coverArtID: coverArt.flatMap { $0.isEmpty ? nil : $0 }
            ),
            disc: discNumber ?? 1,
            number: track
        )
    }
}

private struct StarredPayload: Decodable {
    struct Starred: Decodable {
        let album: [AlbumEntry]?
    }

    let starred2: Starred
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
