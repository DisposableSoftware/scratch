import Foundation

/// Cover art for the signed-in server (LIB-5).
protocol CoverArtUseCase {
    /// The image bytes, or nil when the track has no art or it can't be fetched: art is never
    /// worth an error message.
    func coverArt(id: String, pixelSize: Int) async -> Data?
}

final class DefaultCoverArtUseCase: CoverArtUseCase {
    private let coverArtGateway: CoverArtGateway
    private let sessionState: SessionState

    init(coverArtGateway: CoverArtGateway, sessionState: SessionState) {
        self.coverArtGateway = coverArtGateway
        self.sessionState = sessionState
    }

    func coverArt(id: String, pixelSize: Int) async -> Data? {
        guard let server = sessionState.server, pixelSize > 0 else { return nil }

        return try? await coverArtGateway.coverArt(id: id, size: pixelSize, server: server)
    }
}
