import Foundation
import SwiftUI
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
        AppContainer.build(coordinator: coordinator, networkSession: OfflineSession(), environment: .test, navigationStack: NavigationStackPortStub())
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
    var gate: (() async -> Void)?
    private(set) var requests: [(id: String, pixelSize: Int)] = []

    /// Holds the next request open. `entered` yields once that request is inside the use case;
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

    func coverArt(id: String, pixelSize: Int) async -> Data? {
        requests.append((id, pixelSize))
        if let gate { await gate() }

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
    private(set) var shuffled: [[Track]] = []

    func play(_ tracks: [Track], startingAt index: Int) { played.append((tracks, index)) }

    func playShuffled(_ tracks: [Track]) { shuffled.append(tracks) }

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
    var savedAlbumsPerRow: Int?
    var savedFlavour: Flavour?
    var savedAccent: Accent?

    func transcoding() -> TranscodingSettings? { saved }

    func saveTranscoding(_ settings: TranscodingSettings) { saved = settings }

    func albumsPerRow() -> Int? { savedAlbumsPerRow }

    func saveAlbumsPerRow(_ count: Int) { savedAlbumsPerRow = count }

    func flavour() -> Flavour? { savedFlavour }

    func saveFlavour(_ flavour: Flavour) { savedFlavour = flavour }

    func accent() -> Accent? { savedAccent }

    func saveAccent(_ accent: Accent) { savedAccent = accent }
}

final class DisplayUseCaseMock: DisplayUseCase {
    let state = DisplayState()
    private(set) var calls: [Int] = []
    private(set) var flavours: [Flavour] = []
    private(set) var accents: [Accent] = []

    func setAlbumsPerRow(_ count: Int) {
        calls.append(count)
        state.albumsPerRow = count
    }

    func setFlavour(_ flavour: Flavour) {
        flavours.append(flavour)
        state.flavour = flavour
    }

    func setAccent(_ accent: Accent) {
        accents.append(accent)
        state.accent = accent
    }
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

final class AlbumGatewayMock: AlbumGateway {
    /// Pages are cut from this list by offset and count.
    var all: [Album] = []

    /// What `starredAlbums` returns, in the order given.
    var starred: [Album] = []
    var error: ServerError?
    var starredError: ServerError?
    /// What `album(id:)` returns, by album.
    var details: [Album.ID: AlbumDetail] = [:]
    var albumError: ServerError?
    var albumGate: (() async -> Void)?
    private(set) var albumRequests: [Album.ID] = []

    /// Fail every album request after this many have been made, with `failAfterError`.
    var failAfterRequests: Int?
    var failAfterError = ServerError.unreachable

    /// Answer every page from the start, as a server that ignores the offset would.
    var ignoresOffset = false
    var gate: (() async -> Void)?
    var starredGate: (() async -> Void)?
    private(set) var requests: [(offset: Int, count: Int)] = []
    private(set) var starredRequests = 0

    /// Holds the next album request open. `entered` yields once that request is inside the
    /// gateway; `release` lets it finish. Later requests aren't held.
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

    /// The same for the next favourites request.
    func holdNextStarredRequest() -> (entered: AsyncStream<Void>, release: () -> Void) {
        let (entered, signalEntered) = AsyncStream.makeStream(of: Void.self)
        let (held, release) = AsyncStream.makeStream(of: Void.self)
        starredGate = { [weak self] in
            self?.starredGate = nil
            signalEntered.yield()
            for await _ in held { break }
        }

        return (entered, { release.yield(); release.finish() })
    }

    func albums(offset: Int, count: Int, server: SavedServer) async throws(ServerError) -> [Album] {
        requests.append((offset, count))
        if let gate { await gate() }
        if let error { throw error }
        if let failAfterRequests, requests.count > failAfterRequests { throw failAfterError }

        return Array(all.dropFirst(ignoresOffset ? 0 : offset).prefix(count))
    }

    /// The same for the next `album(id:)` request.
    func holdNextAlbumRequest() -> (entered: AsyncStream<Void>, release: () -> Void) {
        let (entered, signalEntered) = AsyncStream.makeStream(of: Void.self)
        let (held, release) = AsyncStream.makeStream(of: Void.self)
        albumGate = { [weak self] in
            self?.albumGate = nil
            signalEntered.yield()
            for await _ in held { break }
        }

        return (entered, { release.yield(); release.finish() })
    }

    func album(id: Album.ID, server: SavedServer) async throws(ServerError) -> AlbumDetail {
        albumRequests.append(id)
        if let albumGate { await albumGate() }
        if let albumError { throw albumError }
        guard let detail = details[id] else { throw .failed(code: 70, message: "Album not found") }

        return detail
    }

    func starredAlbums(server: SavedServer) async throws(ServerError) -> [Album] {
        starredRequests += 1

        // The answer is what the server held when asked, not when it finishes.
        let answer = starred
        if let starredGate { await starredGate() }
        if let starredError { throw starredError }

        return answer
    }
}

extension Album {
    static func numbered(_ count: Int) -> [Album] {
        (0..<count).map { Album(id: "a\($0)", name: "Album \($0)", artist: "Artist", coverArtID: "ac\($0)", songCount: 10, duration: 2400, year: 2000, genre: "Rock", isStarred: false) }
    }
}

/// A stack that is just its root: nothing is ever pushed in tests.
struct NavigationStackPortStub: NavigationStackPort {
    func stack(root: AnyView) -> AnyView { root }
}

extension AlbumDetail {
    /// An album of `discs` discs with `perDisc` tracks each, in the order a server lists them.
    static func numbered(discs: Int, perDisc: Int, titles: [Int: String] = [:], id: String = "al1") -> AlbumDetail {
        let album = Album(id: id, name: "Chrono Cross", artist: "Mitsuda", coverArtID: "al-\(id)", songCount: discs * perDisc, duration: 7200, year: 2000, genre: "Game", isStarred: false)
        let tracks = (1...discs).flatMap { disc in
            (1...perDisc).map { number in
                AlbumTrack(
                    track: Track(id: "d\(disc)t\(number)", title: "Track \(number)", artist: "Mitsuda", album: "Chrono Cross", duration: 200, coverArtID: "al-\(id)"),
                    disc: disc,
                    number: number
                )
            }
        }

        return AlbumDetail(album: album, tracks: tracks, discTitles: titles)
    }
}
