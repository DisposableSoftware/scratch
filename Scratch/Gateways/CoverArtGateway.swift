import Foundation

/// Cover art images.
protocol CoverArtGateway {
    /// The image bytes for a cover at `size` pixels on its longer side.
    func coverArt(id: String, size: Int, server: SavedServer) async throws(ServerError) -> Data
}

/// Fetches from `getCoverArt` and keeps what it fetched in memory for the session (LIB-5).
final class RemoteCoverArtGateway: CoverArtGateway {
    private let client: SubsonicClient
    private let cache = NSCache<NSString, NSData>()

    init(networkSession: NetworkSession) {
        client = SubsonicClient(session: networkSession)
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func coverArt(id: String, size: Int, server: SavedServer) async throws(ServerError) -> Data {
        let key = "\(server.account.baseURL.absoluteString)|\(id)|\(size)" as NSString

        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        let request = SubsonicRequest(method: "getCoverArt", parameters: [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "size", value: String(size)),
        ])
        let data = try await client.sendForImage(request, to: server)
        cache.setObject(data as NSData, forKey: key, cost: data.count)

        return data
    }
}
