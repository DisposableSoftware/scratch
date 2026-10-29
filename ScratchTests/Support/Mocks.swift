import Foundation
@testable import Scratch

final class ServerGatewayMock: ServerGateway {
    var result: Result<Void, ServerError> = .success(())
    private(set) var pings: [(baseURL: URL, credentials: SubsonicCredentials)] = []

    func ping(baseURL: URL, credentials: SubsonicCredentials) async throws(ServerError) {
        pings.append((baseURL, credentials))
        try result.get()
    }
}

final class CredentialGatewayMock: CredentialGateway {
    var stored: SavedServer?
    var saveError: StorageError?

    init(stored: SavedServer? = nil) {
        self.stored = stored
    }

    func load() -> SavedServer? { stored }

    func save(_ server: SavedServer) throws(StorageError) {
        if let saveError { throw saveError }
        stored = server
    }

    func delete() throws(StorageError) {
        stored = nil
    }
}

final class ConnectUseCaseMock: ConnectUseCase {
    var error: ConnectError?
    private(set) var calls: [(address: String, username: String, password: String)] = []

    func connect(address: String, username: String, password: String) async throws(ConnectError) {
        calls.append((address, username, password))
        if let error { throw error }
    }
}

final class AppRoutingUseCaseSpy: AppRoutingUseCase {
    private(set) var steps: [AppStep] = []

    func navigateToNext(from step: AppStep, with data: AppFlowData) async {
        steps.append(step)
    }
}

enum TestContainer {
    /// The real container over a network that's never reached and storage that's thrown away.
    static func build(coordinator: Coordinator = CoordinatorSpy()) -> AppContainer {
        AppContainer.build(coordinator: coordinator, networkSession: OfflineSession(), environment: .test)
    }
}

/// Every request fails as if offline. Unlike StubURLProtocol, it holds no shared state.
struct OfflineSession: NetworkSession {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

extension AppEnvironment {
    /// Storage for tests, never the app's own. Tests that write to it use a fresh one and remove it.
    static let test = AppEnvironment(defaults: UserDefaults(suiteName: "scratch-tests") ?? .standard, keychainService: "scratch-tests")

    static func fresh() -> AppEnvironment {
        let name = "scratch-tests-\(UUID().uuidString)"
        return AppEnvironment(defaults: UserDefaults(suiteName: name) ?? .standard, keychainService: name)
    }

    func remove() {
        defaults.removePersistentDomain(forName: keychainService)
    }
}

extension SavedServer {
    static let sample = SavedServer(
        account: ServerAccount(baseURL: URL(string: "https://music.example.com")!, username: "me"),
        credentials: SubsonicCredentials(username: "me", salt: "salt", token: "token")
    )
}
