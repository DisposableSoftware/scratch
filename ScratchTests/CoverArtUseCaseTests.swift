import Foundation
import Testing
@testable import Scratch

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
