import Foundation

/// The server's albums.
protocol AlbumGateway {
    /// One page of every album, ordered by name.
    func albums(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Album]

    /// Every album the user has starred, in the order the server gives.
    func starredAlbums(server: SavedServer) async throws(ServerError) -> [Album]

    /// One album and its tracks, in the order the server gives.
    func album(id: Album.ID, server: SavedServer) async throws(ServerError) -> AlbumDetail

    /// Every track the user has starred, in the order the server gives (MIX-5).
    func starredTracks(server: SavedServer) async throws(ServerError) -> [Track]

    /// The albums played most, up to `count` (MIX-5).
    func frequentAlbums(count: Int, server: SavedServer) async throws(ServerError) -> [Album]

    /// The first `count` albums the server lists for `genre` (MIX-14).
    func albums(genre: String, count: Int, server: SavedServer) async throws(ServerError) -> [Album]

    /// `count` albums the server picks at random (MIX-15).
    func randomAlbums(count: Int, server: SavedServer) async throws(ServerError) -> [Album]
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

    /// `getStarred2` lists the starred songs in the same request as the albums.
    func starredTracks(server: SavedServer) async throws(ServerError) -> [Track] {
        let payload = try await client.send(SubsonicRequest(method: "getStarred2"), to: server, as: StarredPayload.self)

        return (payload.starred2.song ?? []).map(\.albumTrack.track)
    }

    /// `getAlbumList2` by play count.
    func frequentAlbums(count: Int, server: SavedServer) async throws(ServerError) -> [Album] {
        let request = SubsonicRequest(method: "getAlbumList2", parameters: [
            URLQueryItem(name: "type", value: "frequent"),
            URLQueryItem(name: "size", value: String(count)),
        ])
        let payload = try await client.send(request, to: server, as: AlbumListPayload.self)

        return (payload.albumList2.album ?? []).map(\.album)
    }

    /// `getAlbumList2` by genre.
    func albums(genre: String, count: Int, server: SavedServer) async throws(ServerError) -> [Album] {
        let request = SubsonicRequest(method: "getAlbumList2", parameters: [
            URLQueryItem(name: "type", value: "byGenre"),
            URLQueryItem(name: "genre", value: genre),
            URLQueryItem(name: "size", value: String(count)),
        ])
        let payload = try await client.send(request, to: server, as: AlbumListPayload.self)

        return (payload.albumList2.album ?? []).map(\.album)
    }

    /// `getAlbumList2` at random.
    func randomAlbums(count: Int, server: SavedServer) async throws(ServerError) -> [Album] {
        let request = SubsonicRequest(method: "getAlbumList2", parameters: [
            URLQueryItem(name: "type", value: "random"),
            URLQueryItem(name: "size", value: String(count)),
        ])
        let payload = try await client.send(request, to: server, as: AlbumListPayload.self)

        return (payload.albumList2.album ?? []).map(\.album)
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

/// A genre as OpenSubsonic lists it, `genres: [{"name": …}]`.
struct GenreEntry: Decodable {
    let name: String?

    /// The first genre's name, or the older single `genre`; nil when there is none.
    static func name(_ genres: [GenreEntry]?, _ genre: String?) -> String? {
        let name = genres?.compactMap(\.name).first { !$0.isEmpty } ?? genre

        return name.flatMap { $0.isEmpty ? nil : $0 }
    }
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
    let starred: String?
    let playCount: Int?
    let year: Int?
    let genre: String?
    let genres: [GenreEntry]?

    var albumTrack: AlbumTrack {
        AlbumTrack(
            track: Track(
                id: id,
                title: title ?? "",
                artist: [displayArtist, artist].compactMap { $0 }.first { !$0.isEmpty } ?? "",
                album: album ?? "",
                duration: duration,
                coverArtID: coverArt.flatMap { $0.isEmpty ? nil : $0 },
                isStarred: starred != nil,
                playCount: playCount,
                year: year,
                genre: GenreEntry.name(genres, genre)
            ),
            disc: discNumber ?? 1,
            number: track
        )
    }
}

private struct StarredPayload: Decodable {
    struct Starred: Decodable {
        let album: [AlbumEntry]?
        let song: [SongEntry]?
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
    let releaseDate: ReleaseDate?

    struct ReleaseDate: Decodable {
        let month: Int?
        let day: Int?
    }

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
            isStarred: starred != nil,
            releaseMonth: releaseDate?.month,
            releaseDay: releaseDate?.day
        )
    }
}
