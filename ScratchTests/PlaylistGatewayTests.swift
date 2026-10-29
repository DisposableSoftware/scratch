import Foundation
import Testing
@testable import Scratch

@Suite(.serialized, .timeLimit(.minutes(1)))
struct PlaylistGatewayTests {
    // PLST-1

    @Test func listsThePlaylistsInOneRequest() async throws {
        let body = #"""
        {"subsonic-response":{"status":"ok","version":"1.16.1","playlists":{"playlist":[
          {"id":"p1","name":"Road trip","owner":"weston","coverArt":"pl-p1","songCount":12,"duration":3600},
          {"id":"p2"},
          {"id":"p3","name":"No art","owner":"","coverArt":""}
        ]}}}
        """#
        let gateway = RemotePlaylistGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let playlists = try await gateway.playlists(server: .sample)

        #expect(playlists == [
            Playlist(id: "p1", name: "Road trip", owner: "weston", coverArtID: "pl-p1", songCount: 12, duration: 3600),
            Playlist(id: "p2", name: "", owner: nil, coverArtID: nil, songCount: nil, duration: nil),
            Playlist(id: "p3", name: "No art", owner: nil, coverArtID: nil, songCount: nil, duration: nil),
        ])
        let url = try #require(StubURLProtocol.requests.first?.url)

        #expect(url.path == "/rest/getPlaylists" && StubURLProtocol.requests.count == 1)
    }

    @Test func aServerWithNoPlaylistsGivesNone() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","playlists":{}}}"#
        let gateway = RemotePlaylistGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        #expect(try await gateway.playlists(server: .sample).isEmpty)
    }

    // PLST-7, PLST-9

    @Test func aPlaylistComesWithItsTracksInOrderAndTheirStars() async throws {
        let body = #"""
        {"subsonic-response":{"status":"ok","version":"1.16.1","playlist":{
          "id":"p1","name":"Road trip","owner":"weston","coverArt":"pl-p1","songCount":3,"duration":600,
          "entry":[
            {"id":"s2","title":"Brink","artist":"Mitsuda","album":"Chrono Cross","duration":212,"coverArt":"al-1","starred":"2026-02-06T11:05:42-05:00"},
            {"id":"s1","title":"Scars"},
            {"id":"s2","title":"Brink","artist":"Mitsuda","album":"Chrono Cross","duration":212,"coverArt":"al-1","starred":"2026-02-06T11:05:42-05:00"}
          ]}}}
        """#
        let gateway = RemotePlaylistGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let detail = try await gateway.playlist(id: "p1", server: .sample)

        #expect(detail.playlist == Playlist(id: "p1", name: "Road trip", owner: "weston", coverArtID: "pl-p1", songCount: 3, duration: 600))
        #expect(detail.tracks.map(\.id) == ["s2", "s1", "s2"])
        #expect(detail.tracks.map(\.isStarred) == [true, false, true])
        #expect(detail.tracks[0] == Track(id: "s2", title: "Brink", artist: "Mitsuda", album: "Chrono Cross", duration: 212, coverArtID: "al-1", isStarred: true))
        let url = try #require(StubURLProtocol.requests.first?.url)

        #expect(url.path == "/rest/getPlaylist" && url.query?.contains("id=p1") == true)
    }

    @Test func aPlaylistWithNoEntriesHasNoTracks() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","playlist":{"id":"p1","name":"Empty"}}}"#
        let gateway = RemotePlaylistGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        #expect(try await gateway.playlist(id: "p1", server: .sample).tracks.isEmpty)
    }

    @Test func aServerErrorIsPassedOn() async {
        let body = #"{"subsonic-response":{"status":"failed","version":"1.16.1","error":{"code":70,"message":"Playlist not found"}}}"#
        let gateway = RemotePlaylistGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        await #expect(throws: ServerError.failed(code: 70, message: "Playlist not found")) {
            try await gateway.playlist(id: "nope", server: .sample)
        }
    }
}
