import Foundation
import UIKit
import Testing
@testable import Scratch

/// Connects to a real server. Skipped unless scripts/manual/live-connect.sh passes one in, so the
/// normal test run never touches the network. Credentials come only from the environment.
@Suite(.serialized, .enabled(if: LiveServer.configured), .timeLimit(.minutes(1)))
struct LiveServerTests {
    /// The app's own storage, so a launch afterwards finds the saved server (SRV-5).
    private let container = AppContainer.build(coordinator: CoordinatorSpy(), networkSession: URLSession.shared, environment: .live, navigationStack: NavigationStackPortStub())

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
        player.load(track, server: server, quality: TranscodingSettings.defaults.wifi)
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
        player.load(missing, server: server, quality: TranscodingSettings.defaults.wifi)
        var failed = false

        for await event in failures {
            if case .failed = event { failed = true; break }
            if case .ready = event { break }
        }

        player.stop()

        #expect(failed)
    }

    /// TRANS-4 against the real server: each quality streams as what it asks for, plays, and a
    /// transcoded stream can be sought into.
    @Test(arguments: [
        (StreamQuality(format: .mp3, maxBitRate: 128), "audio/mpeg"),
        (StreamQuality(format: .aac, maxBitRate: 128), "audio/aac"),
        (StreamQuality(format: .original, maxBitRate: nil), ""),
    ])

    func streamsAsAskedPlayAndSeek(quality: StreamQuality, contentType: String) async throws {
        try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password)
        let server = try #require(KeychainCredentialGateway(environment: .live).load())
        let track = try #require(try await RemoteLibraryGateway(networkSession: URLSession.shared).tracks(offset: 0, count: 1, server: server).first)

        if !contentType.isEmpty {
            let url = try SubsonicRequest.stream(trackID: track.id, quality: quality).url(baseURL: server.account.baseURL, credentials: server.credentials)
            var head = URLRequest(url: url)
            head.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            let (_, response) = try await URLSession.shared.data(for: head)

            #expect((response as? HTTPURLResponse)?.mimeType == contentType)
        }

        let player = AVPlayerAudioGateway()
        let (events, sink) = AsyncStream.makeStream(of: AudioPlayerEvent.self)
        player.onEvent = { sink.yield($0) }
        player.load(track, server: server, quality: quality)
        var played = false
        var sought = false

        for await event in events {
            if case .failed = event { break }

            if case .time(let t) = event {
                if !played, t > 1 {
                    played = true
                    player.seek(to: 60)
                } else if played, t > 59 {
                    sought = true
                    break
                }
            }
        }

        player.stop()

        #expect(played && sought, "\(quality.format): played \(played), sought \(sought)")
    }

    /// SRV-6 against the real server: a library request with credentials it no longer accepts
    /// fails as rejected credentials, which sends the app back to setup.
    @Test func staleCredentialsAreRejected() async throws {
        let address = try ServerAddress.parse(LiveServer.address)
        let stale = SavedServer(
            account: ServerAccount(baseURL: address, username: LiveServer.username),
            credentials: SubsonicCredentials.derive(username: LiveServer.username, password: LiveServer.password + "-old")
        )

        do {
            _ = try await RemoteLibraryGateway(networkSession: URLSession.shared).tracks(offset: 0, count: 1, server: stale)
            Issue.record("the server accepted stale credentials")
        } catch {
            #expect(error.rejectsCredentials, "got \(error)")
        }
    }

    /// ALB-2, ALB-4 against the real server: a page of albums with names and artists, and the next
    /// page continuing where it stopped.
    @Test func albumsPageInByName() async throws {
        try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password)
        let server = try #require(KeychainCredentialGateway(environment: .live).load())
        let gateway = RemoteAlbumGateway(networkSession: URLSession.shared)

        let first = try await gateway.albums(offset: 0, count: 100, server: server)
        let second = try await gateway.albums(offset: 100, count: 100, server: server)

        #expect(!first.isEmpty && first.count <= 100)
        #expect(first.allSatisfy { !$0.name.isEmpty })
        #expect(Set(first.map(\.id)).isDisjoint(with: second.map(\.id)))
    }

    /// ALB-3 against the real server: the starred albums come first, by name, and aren't repeated.
    @Test func favouritesComeFirstAndAreNotRepeated() async throws {
        try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password)

        try await container.albumUseCase.loadFirstPage()

        let favourites = container.albumUseCase.favourites
        let names = favourites.map { $0.name }
        let ordered = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let others = Set(container.albumUseCase.albums.map { $0.id })

        #expect(favourites.allSatisfy { $0.isStarred })
        #expect(names == ordered)
        #expect(Set(favourites.map { $0.id }).isDisjoint(with: others))
    }

    /// ALB-9 to ALB-12 against the real server: an album's tracks arrive in disc and track order,
    /// and a multi-disc album groups into discs. With SCRATCH_SNAPSHOT_DIR set, the album screens
    /// (a multi-disc one if the library has one, and a single-disc one) are saved as PNGs.
    @Test func albumScreensShowTracksByDisc() async throws {
        try await container.connectUseCase.connect(address: LiveServer.address, username: LiveServer.username, password: LiveServer.password)
        try await container.albumUseCase.loadFirstPage()
        let candidates = container.albumUseCase.albums.filter { ($0.songCount ?? 0) >= 14 }.prefix(40)

        var multiDisc: AlbumDetail?
        var singleDisc: AlbumDetail?
        for album in candidates {
            guard let detail = try await container.albumUseCase.album(id: album.id) else { continue }

            let order = detail.tracks.map { [$0.disc, $0.number ?? Int.max] }

            #expect(order == order.sorted { ($0[0], $0[1]) < ($1[0], $1[1]) }, "\(album.name) isn't in disc and track order")
            #expect(detail.discs.flatMap { $0.tracks }.count == detail.tracks.count)
            if detail.discs.count > 1, multiDisc == nil { multiDisc = detail }
            if detail.discs.count == 1, singleDisc == nil { singleDisc = detail }
            if multiDisc != nil, singleDisc != nil { break }
        }

        #expect(multiDisc != nil || singleDisc != nil, "no album with 14 or more tracks in the first page")

        guard let directory = LiveServer.snapshotDirectory else { return }

        for (name, detail) in [("alb9-album-multi-disc", multiDisc), ("alb9-album-single-disc", singleDisc)] {
            guard let detail else { continue }

            let viewModel = AlbumViewModel(album: detail.album, useCases: container)
            _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
            _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 1080))
            let image = await WindowSnapshot.image(of: AlbumView(viewModel: viewModel), size: CGSize(width: 402, height: 874))
            let png = try #require(image?.pngData())
            try png.write(to: URL(fileURLWithPath: directory).appending(path: "\(name).png"))
        }
    }

    /// ALB-16 against the real server: an album request signed with credentials it no longer
    /// accepts comes back as a rejection, which sends the app to setup. One bad request is enough,
    /// since every request goes through the same client, and Navidrome allows only a few failed
    /// sign-ins in a short window (five in twenty seconds by default): this suite makes three, and
    /// a fourth would lock the valid sign-ins out.
    @Test func staleCredentialsAreRejectedByAlbumRequests() async throws {
        let address = try ServerAddress.parse(LiveServer.address)
        let stale = SavedServer(
            account: ServerAccount(baseURL: address, username: LiveServer.username),
            credentials: SubsonicCredentials.derive(username: LiveServer.username, password: LiveServer.password + "-old")
        )

        do {
            _ = try await RemoteAlbumGateway(networkSession: URLSession.shared).albums(offset: 0, count: 10, server: stale)
            Issue.record("the server accepted stale credentials")
        } catch {
            #expect(error.rejectsCredentials, "\(error)")
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
    static var snapshotDirectory: String? { environment["SCRATCH_SNAPSHOT_DIR"] }
}
