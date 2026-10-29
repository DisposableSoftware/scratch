import Foundation

/// Connecting to a server from the setup screen (SRV-3).
protocol ConnectUseCase {
    func connect(address: String, username: String, password: String) async throws(ConnectError)
}

final class DefaultConnectUseCase: ConnectUseCase {
    private let serverGateway: ServerGateway
    private let credentialGateway: CredentialGateway
    private let sessionState: SessionState

    init(serverGateway: ServerGateway, credentialGateway: CredentialGateway, sessionState: SessionState) {
        self.serverGateway = serverGateway
        self.credentialGateway = credentialGateway
        self.sessionState = sessionState
    }

    /// Checks the server with `ping`, and only then saves it and signs in.
    func connect(address: String, username: String, password: String) async throws(ConnectError) {
        let baseURL: URL
        do {
            baseURL = try ServerAddress.parse(address)
        } catch {
            throw .invalidAddress(error)
        }
        let credentials = SubsonicCredentials.derive(username: username, password: password)
        do {
            try await serverGateway.ping(baseURL: baseURL, credentials: credentials)
        } catch {
            throw .server(error)
        }
        let server = SavedServer(account: ServerAccount(baseURL: baseURL, username: username), credentials: credentials)
        do {
            try credentialGateway.save(server)
        } catch {
            throw .couldNotSave
        }
        sessionState.server = server
    }
}
