import Foundation
import Testing
@testable import Scratch

@Suite(.serialized)
struct LibraryGatewayTests {
    @Test func asksSearch3ForOnePageOfSongs() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","searchResult3":{"song":[{"id":"a","title":"You gave away","album":"Live","artist":"Mars Argo","duration":224,"coverArt":"dc-1"},{"id":"b"}]}}}"#
        let gateway = RemoteLibraryGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })

        let tracks = try await gateway.tracks(offset: 200, count: 100, server: .sample)

        #expect(tracks == [
            Track(id: "a", title: "You gave away", artist: "Mars Argo", album: "Live", duration: 224, coverArtID: "dc-1"),
            Track(id: "b", title: "", artist: "", album: "", duration: nil, coverArtID: nil),
        ])
        let url = try #require(StubURLProtocol.requests.first?.url)
        #expect(url.path == "/rest/search3")
        for part in ["query=", "songCount=100", "songOffset=200", "artistCount=0", "albumCount=0"] {
            #expect(url.query?.contains(part) == true, "missing \(part)")
        }
    }

    @Test func aPageWithNoSongsIsEmpty() async throws {
        let body = #"{"subsonic-response":{"status":"ok","version":"1.16.1","searchResult3":{}}}"#
        let gateway = RemoteLibraryGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: body) })
        #expect(try await gateway.tracks(offset: 0, count: 100, server: .sample).isEmpty)
    }
}

@Suite(.serialized)
struct CoverArtGatewayTests {
    @Test func fetchesAtTheRequestedSizeAndCachesIt() async throws {
        let gateway = RemoteCoverArtGateway(networkSession: StubURLProtocol.session { _ in .image("PNGDATA") })

        let first = try await gateway.coverArt(id: "c1", size: 144, server: .sample)
        let second = try await gateway.coverArt(id: "c1", size: 144, server: .sample)
        _ = try await gateway.coverArt(id: "c1", size: 300, server: .sample)

        #expect(first == Data("PNGDATA".utf8) && second == first)
        #expect(StubURLProtocol.requests.count == 2)
        let url = try #require(StubURLProtocol.requests.first?.url)
        #expect(url.path == "/rest/getCoverArt")
        #expect(url.query?.contains("id=c1") == true && url.query?.contains("size=144") == true)
    }

    @Test func anImageWithoutAContentTypeStillCounts() async throws {
        let gateway = RemoteCoverArtGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: "JPEGDATA") })
        #expect(try await gateway.coverArt(id: "c1", size: 144, server: .sample) == Data("JPEGDATA".utf8))
    }

    @Test func aSubsonicErrorInsteadOfAnImageIsAnError() async {
        let gateway = RemoteCoverArtGateway(networkSession: StubURLProtocol.session { _ in .http(status: 200, body: SubsonicReply.error(70, "Not found")) })
        await #expect(throws: ServerError.failed(code: 70, message: "Not found")) {
            try await gateway.coverArt(id: "missing", size: 144, server: .sample)
        }
    }
}

struct CoverArtUseCaseTests {
    private final class Gateway: CoverArtGateway {
        var result: Result<Data, ServerError> = .success(Data("img".utf8))
        private(set) var sizes: [Int] = []

        func coverArt(id: String, size: Int, server: SavedServer) async throws(ServerError) -> Data {
            sizes.append(size)
            return try result.get()
        }
    }

    @Test func fetchesForTheSignedInServerAtTheGivenSize() async {
        let gateway = Gateway()
        let data = await DefaultCoverArtUseCase(coverArtGateway: gateway, sessionState: SessionState(server: .sample)).coverArt(id: "c", pixelSize: 144)
        #expect(data == Data("img".utf8) && gateway.sizes == [144])
    }

    @Test func aFailureIsJustNoArt() async {
        let gateway = Gateway()
        gateway.result = .failure(.unreachable)
        #expect(await DefaultCoverArtUseCase(coverArtGateway: gateway, sessionState: SessionState(server: .sample)).coverArt(id: "c", pixelSize: 144) == nil)
    }

    @Test func nothingIsFetchedSignedOutOrAtNoSize() async {
        let gateway = Gateway()
        #expect(await DefaultCoverArtUseCase(coverArtGateway: gateway, sessionState: SessionState()).coverArt(id: "c", pixelSize: 144) == nil)
        #expect(await DefaultCoverArtUseCase(coverArtGateway: gateway, sessionState: SessionState(server: .sample)).coverArt(id: "c", pixelSize: 0) == nil)
        #expect(gateway.sizes.isEmpty)
    }
}
