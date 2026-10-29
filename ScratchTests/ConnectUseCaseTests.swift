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

    @Test func connectingForgetsARejectedAccount() async throws {
        session.rejectedAccount = SavedServer.sample.account
        try await useCase.connect(address: "music.example.com", username: "me", password: "secret")
        #expect(session.rejectedAccount == nil)
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
    private let storage = CredentialGatewayMock(stored: .sample)
    private let playback = PlaybackUseCaseMock()
    private let session = SessionState()
    private let library = LibraryState()
    private let albums = AlbumsState()
    private var useCase: DefaultSessionUseCase {
        DefaultSessionUseCase(credentialGateway: storage, playback: playback, sessionState: session, libraryState: library, albumsState: albums)
    }

    @Test func restoresTheSavedServer() {
        useCase.restoreSavedServer()
        #expect(session.server == .sample)
    }

    @Test func staysSignedOutWithNothingSaved() {
        storage.stored = nil
        useCase.restoreSavedServer()
        #expect(session.server == nil)
    }

    @Test func signingOutStopsPlaybackAndForgetsEverything() {
        let useCase = useCase
        useCase.restoreSavedServer()
        library.tracks = Track.numbered(3)
        library.hasMoreTracks = false
        albums.albums = Album.numbered(3)
        albums.hasMoreAlbums = false
        albums.nextOffset = 100

        useCase.signOut()

        #expect(playback.stops == 1)
        #expect(storage.stored == nil && session.server == nil && useCase.account == nil)
        #expect(library.tracks.isEmpty && library.hasMoreTracks)
        #expect(albums.albums.isEmpty && albums.hasMoreAlbums && albums.nextOffset == 0)
        #expect(useCase.rejectedAccount == nil)
    }

    @Test func aSignOutHoldsEvenIfTheKeychainRefuses() {
        storage.deleteError = .keychain(status: -1)
        let useCase = useCase
        useCase.restoreSavedServer()

        useCase.signOut()

        #expect(session.server == nil && playback.stops == 1)
    }

    @Test func aSecondRejectionKeepsTheRememberedAccount() {
        let useCase = useCase
        useCase.restoreSavedServer()
        useCase.credentialsRejected()

        useCase.credentialsRejected()

        #expect(useCase.rejectedAccount == SavedServer.sample.account)
        #expect(playback.stops == 1)
    }

    @Test func aRejectionSignsOutButRemembersTheAccount() {
        let useCase = useCase
        useCase.restoreSavedServer()

        useCase.credentialsRejected()

        #expect(playback.stops == 1 && storage.stored == nil && session.server == nil)
        #expect(useCase.rejectedAccount == SavedServer.sample.account)
    }
}

struct ServerErrorTests {
    @Test func onlyErrors40And41RejectTheCredentials() {
        #expect(ServerError.wrongCredentials.rejectsCredentials)
        #expect(ServerError.failed(code: 41, message: "").rejectsCredentials)
        #expect(!ServerError.failed(code: 50, message: "").rejectsCredentials)
        #expect(!ServerError.unreachable.rejectsCredentials)
        #expect(!ServerError.notSubsonic.rejectsCredentials)
    }
}
