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
    var deleteError: StorageError?

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
        if let deleteError { throw deleteError }
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

final class LibraryGatewayMock: LibraryGateway {
    /// Pages are cut from this list by offset and count.
    var all: [Track] = []
    var error: ServerError?
    /// Lets a test hold a request open while it does something else.
    var gate: (() async -> Void)?

    /// Holds the next request open. `entered` yields once that request is inside the gateway;
    /// `release` lets it finish. Later requests aren't held.
    func holdNextRequest() -> (entered: AsyncStream<Void>, release: () -> Void) {
        let (entered, signalEntered) = AsyncStream.makeStream(of: Void.self)
        let (held, release) = AsyncStream.makeStream(of: Void.self)
        gate = { [weak self] in
            self?.gate = nil
            signalEntered.yield()
            for await _ in held { break }
        }
        return (entered, { release.yield(); release.finish() })
    }
    private(set) var requests: [(offset: Int, count: Int)] = []

    func tracks(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Track] {
        requests.append((offset, count))
        if let gate { await gate() }
        if let error { throw error }
        return Array(all.dropFirst(offset).prefix(count))
    }
}

final class CoverArtUseCaseMock: CoverArtUseCase {
    var data: Data?
    private(set) var requests: [(id: String, pixelSize: Int)] = []

    func coverArt(id: String, pixelSize: Int) async -> Data? {
        requests.append((id, pixelSize))
        return data
    }
}

extension Track {
    static func numbered(_ count: Int) -> [Track] {
        (0..<count).map { Track(id: "t\($0)", title: "Song \($0)", artist: "Artist", album: "Album", duration: 200, coverArtID: "c\($0)") }
    }
}

final class AudioPlayerGatewayMock: AudioPlayerGateway {
    enum Call: Equatable {
        case load(Track.ID, StreamQuality)
        case play, pause, stop
        case seek(TimeInterval)
    }

    var onEvent: ((AudioPlayerEvent) -> Void)?
    var currentTime: TimeInterval = 0
    private(set) var calls: [Call] = []

    func load(_ track: Track, server: SavedServer, quality: StreamQuality) { calls.append(.load(track.id, quality)) }
    func play() { calls.append(.play) }
    func pause() { calls.append(.pause) }
    func seek(to seconds: TimeInterval) { calls.append(.seek(seconds)) }
    func stop() { calls.append(.stop) }

    func send(_ event: AudioPlayerEvent) { onEvent?(event) }
    var loads: [Track.ID] { calls.compactMap { if case .load(let id, _) = $0 { id } else { nil } } }
    var qualities: [StreamQuality] { calls.compactMap { if case .load(_, let quality) = $0 { quality } else { nil } } }
}

final class PlaybackUseCaseMock: PlaybackUseCase {
    let state = PlaybackState()
    private(set) var played: [(tracks: [Track], index: Int)] = []

    func play(_ tracks: [Track], startingAt index: Int) { played.append((tracks, index)) }
    func togglePlayPause() {}
    func next() {}
    func previous() {}
    func seek(to seconds: TimeInterval) {}
    private(set) var stops = 0
    func stop() { stops += 1 }
}

final class NowPlayingGatewayMock: NowPlayingGateway {
    var onCommand: ((RemoteCommand) -> Void)?
    private(set) var updates: [NowPlayingInfo?] = []
    var last: NowPlayingInfo? { updates.last ?? nil }

    func update(_ info: NowPlayingInfo?) { updates.append(info) }
    func send(_ command: RemoteCommand) { onCommand?(command) }
}

final class TranscodingUseCaseMock: TranscodingUseCase {
    var settings = TranscodingSettings.defaults
    var network = NetworkKind.wifi

    func update(_ settings: TranscodingSettings) { self.settings = settings }
    func qualityForNextTrack() -> StreamQuality { settings.quality(on: network) }
}

final class NetworkGatewayStub: NetworkGateway {
    var currentNetwork = NetworkKind.wifi
}

final class SettingsGatewayMock: SettingsGateway {
    private(set) var saved: TranscodingSettings?

    func transcoding() -> TranscodingSettings? { saved }
    func saveTranscoding(_ settings: TranscodingSettings) { saved = settings }
}

final class SessionUseCaseMock: SessionUseCase {
    var account: ServerAccount? = SavedServer.sample.account
    var rejectedAccount: ServerAccount?
    private(set) var rejections = 0
    private(set) var signOuts = 0

    func restoreSavedServer() {}
    func credentialsRejected() {
        rejections += 1
        guard let account else { return }
        rejectedAccount = account
        self.account = nil
    }

    func signOut() {
        signOuts += 1
        account = nil
        rejectedAccount = nil
    }
}
