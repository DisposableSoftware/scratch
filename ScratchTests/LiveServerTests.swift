import Foundation
import Testing
@testable import Scratch

/// Connects to a real server. Skipped unless scripts/manual/live-connect.sh passes one in, so the
/// normal test run never touches the network. Credentials come only from the environment.
@Suite(.serialized, .enabled(if: LiveServer.configured))
struct LiveServerTests {
    /// The app's own storage, so a launch afterwards finds the saved server (SRV-5).
    private let container = AppContainer.build(coordinator: CoordinatorSpy(), networkSession: URLSession.shared, environment: .live)

    @Test func aWrongPasswordIsRejected() async {
        await #expect(throws: ConnectError.server(.wrongCredentials)) {
            try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password + "x")
        }
    }

    @Test func aWebPageIsNotASubsonicServer() async {
        await #expect(throws: ConnectError.server(.notSubsonic)) {
            try await container.connectUseCase.connect(address: "https://www.apple.com", username: "me", password: "pw")
        }
    }

    @Test func nothingListeningIsUnreachable() async {
        await #expect(throws: ConnectError.server(.unreachable)) {
            try await container.connectUseCase.connect(address: "http://127.0.0.1:9", username: "me", password: "pw")
        }
    }

    @Test func connectsAndSavesTheServer() async throws {
        try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password)

        let saved = KeychainCredentialGateway(environment: .live).load()
        #expect(saved?.account.username == LiveServer.username)
        // SRV-4: the password is in neither store.
        let defaults = AppEnvironment.live.defaults.dictionaryRepresentation().values.compactMap { $0 as? String }
        #expect(!defaults.contains { $0.contains(LiveServer.password) })
        #expect(saved.map { $0.credentials.token != LiveServer.password && $0.credentials.salt != LiveServer.password } == true)
    }
}

nonisolated enum LiveServer {
    static let environment = ProcessInfo.processInfo.environment
    static var configured: Bool { environment["SCRATCH_SERVER"] != nil }
    static var address: String { environment["SCRATCH_SERVER"] ?? "" }
    static var username: String { environment["SCRATCH_USER"] ?? "" }
    static var password: String { environment["SCRATCH_PASSWORD"] ?? "" }
}
