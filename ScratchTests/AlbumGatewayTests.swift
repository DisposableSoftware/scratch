import Foundation
import Testing
@testable import Scratch

@Suite(.serialized)
struct AlbumGatewayTests {
    @Test func asksGetAlbumList2ByNameForOnePage() async throws {
        let body = #"""
        {"subsonic-response":{"status":"ok","version":"1.16.1","albumList2":{"album":[
          {"id":"a","name":"Chrono Cross","artist":"Yasunori Mitsuda","displayArtist":"Yasunori Mitsuda & Others","coverArt":"al-a","songCount":67,"duration":7200,"year":2000,"genre":"Game","starred":"2026-02-06T11:05:42-05:00"},
          {"id":"b"}
        ]}}}
        """#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let albums = try await gateway.albums(offset: 200, count: 100, server: .sample)

        #expect(albums == [
            Album(id: "a", name: "Chrono Cross", artist: "Yasunori Mitsuda & Others", coverArtID: "al-a", songCount: 67, duration: 7200, year: 2000, genre: "Game", isStarred: true),
            Album(id: "b", name: "", artist: "", coverArtID: nil, songCount: nil, duration: nil, year: nil, genre: nil, isStarred: false),
        ])
        let url = try #require(StubURLProtocol.requests.first?.url)

        #expect(url.path == "/rest/getAlbumList2")

        for part in ["type=alphabeticalByName", "size=100", "offset=200"] {
            #expect(url.query?.contains(part) == true, "missing \(part)")
        }
    }

    @Test func usesTheArtistWhenThereIsNoDisplayArtist() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","albumList2":{"album":[{"id":"a","name":"X","artist":"Solo"}]}}}"#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        #expect(try await gateway.albums(offset: 0, count: 100, server: .sample).first?.artist == "Solo")
    }

    @Test func emptyStringsCountAsMissing() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","albumList2":{"album":[{"id":"a","name":"X","artist":"Solo","displayArtist":"","coverArt":""}]}}}"#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let album = try #require(try await gateway.albums(offset: 0, count: 100, server: .sample).first)

        #expect(album.artist == "Solo" && album.coverArtID == nil && !album.isStarred)
    }

    @Test func aReplyWithoutTheListKeyIsNotSubsonic() async {
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: SubsonicReply.ok) })

        await #expect(throws: ServerError.notSubsonic) {
            try await gateway.albums(offset: 0, count: 100, server: .sample)
        }
    }

    @Test func asksGetStarred2ForTheStarredAlbums() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","starred2":{"album":[{"id":"a","name":"Fire","artist":"Someone","coverArt":"al-a","starred":"2026-02-06T11:05:42-05:00"}],"song":[{"id":"s"}],"artist":[]}}}"#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let albums = try await gateway.starredAlbums(server: .sample)

        #expect(albums.map(\.id) == ["a"] && albums.first?.isStarred == true && albums.first?.name == "Fire")
        #expect(StubURLProtocol.requests.first?.url?.path == "/rest/getStarred2")
    }

    @Test func aStarredReplyWithoutTheKeyIsNotSubsonic() async {
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: SubsonicReply.ok) })

        await #expect(throws: ServerError.notSubsonic) {
            try await gateway.starredAlbums(server: .sample)
        }
    }

    @Test func nothingStarredIsEmpty() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","starred2":{}}}"#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        #expect(try await gateway.starredAlbums(server: .sample).isEmpty)
    }

    // getAlbum

    @Test func asksGetAlbumAndReadsTheTracksDiscsAndDiscTitles() async throws {
        let body = #"""
        {"subsonic-response":{"status":"ok","version":"1.16.1","album":{
          "id":"al1","name":"Chrono Cross","artist":"Mitsuda","coverArt":"al-al1","songCount":3,"duration":600,"year":2000,"genre":"Game",
          "discTitles":[{"disc":1,"title":"Opening"},{"disc":2,"title":"Development"},{"disc":3,"title":""}],
          "song":[
            {"id":"s1","title":"Scars","artist":"Mitsuda","displayArtist":"Mitsuda & Guest","album":"Chrono Cross","duration":212,"coverArt":"al-al1","track":1,"discNumber":1},
            {"id":"s2","title":"No disc"},
            {"id":"s3","title":"Brink","track":5,"discNumber":2,"coverArt":"","starred":"2026-02-06T11:05:42-05:00"}
          ]}}}
        """#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let detail = try await gateway.album(id: "al1", server: .sample)

        #expect(detail.album.name == "Chrono Cross" && detail.album.year == 2000 && detail.album.songCount == 3)
        #expect(detail.discTitles == [1: "Opening", 2: "Development"])
        #expect(detail.tracks.map(\.id) == ["s1", "s2", "s3"])
        #expect(detail.tracks[0] == AlbumTrack(track: Track(id: "s1", title: "Scars", artist: "Mitsuda & Guest", album: "Chrono Cross", duration: 212, coverArtID: "al-al1"), disc: 1, number: 1))
        #expect(detail.tracks[1].disc == 1 && detail.tracks[1].number == nil)
        #expect(detail.tracks.map(\.track.isStarred) == [false, false, true])
        #expect(detail.tracks[2].disc == 2 && detail.tracks[2].number == 5 && detail.tracks[2].track.coverArtID == nil)
        let url = try #require(StubURLProtocol.requests.first?.url)

        #expect(url.path == "/rest/getAlbum" && url.query?.contains("id=al1") == true)
    }

    @Test func anAlbumWithNoSongsHasNoTracks() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","album":{"id":"al1","name":"Empty"}}}"#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })
        let detail = try await gateway.album(id: "al1", server: .sample)

        #expect(detail.tracks.isEmpty && detail.discTitles.isEmpty)
    }

    @Test func anAlbumTheServerDoesntHaveIsAnError() async {
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: SubsonicReply.error(70, "Album not found")) })

        await #expect(throws: ServerError.failed(code: 70, message: "Album not found")) {
            try await gateway.album(id: "nope", server: .sample)
        }
    }

    @Test func aReplyWithoutTheAlbumKeyIsNotSubsonic() async {
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: SubsonicReply.ok) })

        await #expect(throws: ServerError.notSubsonic) {
            try await gateway.album(id: "al1", server: .sample)
        }
    }

    @Test func aPageWithNoAlbumsIsEmpty() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","albumList2":{}}}"#
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        #expect(try await gateway.albums(offset: 0, count: 100, server: .sample).isEmpty)
    }

    @Test func aRejectedRequestIsAnError() async {
        let gateway = RemoteAlbumGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: SubsonicReply.error(40, "Wrong username or password")) })

        await #expect(throws: ServerError.wrongCredentials) {
            try await gateway.albums(offset: 0, count: 100, server: .sample)
        }
    }
}
