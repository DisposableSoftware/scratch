import Foundation
import Testing
@testable import Scratch

struct ConnectUseCaseTests {
    private let server = ServerGatewayMock()
    private let storage = CredentialGatewayMock()
    private let session = SessionState()
    private var useCase: DefaultConnectUseCase {
        DefaultConnectUseCase(serverGateway: server, credentialGateway: storage, sessionState: session)
    }

    @Test func pingsThenSavesAndSignsIn() async throws {
        try await useCase.connect(address: "music.example.com/nd/", username: "me", password: "secret")

        let ping = try #require(server.pings.first)
        #expect(ping.baseURL.absoluteString == "https://music.example.com/nd")
        #expect(ping.credentials == SubsonicCredentials.derive(username: "me", password: "secret", salt: ping.credentials.salt))
        #expect(storage.stored == session.server)
        #expect(session.server?.account == ServerAccount(baseURL: ping.baseURL, username: "me"))
        #expect(session.server?.credentials == ping.credentials)
    }

    @Test(arguments: [ServerError.unreachable, .wrongCredentials, .notSubsonic, .failed(code: 0, message: "x")])
    func aFailedPingSavesNothing(error: ServerError) async {
        server.result = .failure(error)

        await #expect(throws: ConnectError.server(error)) {
            try await useCase.connect(address: "music.example.com", username: "me", password: "secret")
        }
        #expect(storage.stored == nil)
        #expect(session.server == nil)
    }

    @Test func aBadAddressNeverReachesTheServer() async {
        await #expect(throws: ConnectError.invalidAddress(.unsupportedScheme("ftp"))) {
            try await useCase.connect(address: "ftp://example.com", username: "me", password: "secret")
        }
        #expect(server.pings.isEmpty)
    }

    @Test func aStorageFailureLeavesTheUserSignedOut() async {
        storage.saveError = .keychain(status: -1)

        await #expect(throws: ConnectError.couldNotSave) {
            try await useCase.connect(address: "music.example.com", username: "me", password: "secret")
        }
        #expect(session.server == nil)
    }
}

struct SessionUseCaseTests {
    @Test func restoresTheSavedServer() {
        let session = SessionState()
        DefaultSessionUseCase(credentialGateway: CredentialGatewayMock(stored: .sample), sessionState: session).restoreSavedServer()
        #expect(session.server == .sample)
    }

    @Test func staysSignedOutWithNothingSaved() {
        let session = SessionState()
        DefaultSessionUseCase(credentialGateway: CredentialGatewayMock(), sessionState: session).restoreSavedServer()
        #expect(session.server == nil)
    }
}
