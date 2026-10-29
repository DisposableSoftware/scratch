import Foundation

/// The server itself: is it there, and does it accept these credentials.
protocol ServerGateway {
    func ping(baseURL: URL, credentials: SubsonicCredentials) async throws(ServerError)
}

final class RemoteServerGateway: ServerGateway {
    private let client: SubsonicClient

    init(networkSession: NetworkSession) {
        client = SubsonicClient(session: networkSession)
    }

    func ping(baseURL: URL, credentials: SubsonicCredentials) async throws(ServerError) {
        _ = try await client.send(SubsonicRequest(method: "ping"), baseURL: baseURL, credentials: credentials, as: NoPayload.self)
    }
}
