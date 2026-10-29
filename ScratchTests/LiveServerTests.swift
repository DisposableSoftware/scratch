import Foundation
import Testing
@testable import Scratch

/// Connects to a real server. Skipped unless scripts/manual/live-connect.sh passes one in, so the
/// normal test run never touches the network. Credentials come only from the environment.
@Suite(.serialized, .enabled(if: LiveServer.configured), .timeLimit(.minutes(1)))
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

    /// PLAY-1 and PLAY-8 against the real server: a track's stream becomes playable and its
    /// time moves; a stream for a track that doesn't exist fails.
    @Test func streamsATrackAndFailsOnAMissingOne() async throws {
        try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password)
        let server = try #require(KeychainCredentialGateway(environment: .live).load())
        let track = try #require(try await RemoteLibraryGateway(networkSession: URLSession.shared).tracks(offset: 0, count: 1, server: server).first)

        let player = AVPlayerAudioGateway()
        let (events, sink) = AsyncStream.makeStream(of: AudioPlayerEvent.self)
        player.onEvent = { sink.yield($0) }
        player.load(track, server: server)
        var ready = false
        var played: TimeInterval = 0
        for await event in events {
            if case .ready = event { ready = true }
            if case .time(let t) = event { played = t }
            if case .failed = event { break }
            if ready && played > 1 { break }
        }
        #expect(ready && played > 1)

        var missing = track
        missing.id = "no-such-track"
        let (failures, failureSink) = AsyncStream.makeStream(of: AudioPlayerEvent.self)
        player.onEvent = { failureSink.yield($0) }
        player.load(missing, server: server)
        var failed = false
        for await event in failures {
            if case .failed = event { failed = true; break }
            if case .ready = event { break }
        }
        player.stop()
        #expect(failed)
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
