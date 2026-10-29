import Foundation
import Testing
import UIKit
@testable import Scratch

private struct PlaylistUseCases: HasPlaylistUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasSessionUseCase, HasAppRoutingUseCase {
    let playlistUseCase: PlaylistUseCase
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
    let sessionUseCase: SessionUseCase
    let appRouting: AppRoutingUseCase
}

@Suite(.timeLimit(.minutes(1)))
struct PlaylistViewModelTests {
    private let gateway = PlaylistGatewayMock()
    private let art = CoverArtUseCaseMock()
    private let playback = PlaybackUseCaseMock()
    private let session = SessionUseCaseMock()
    private let routing = AppRoutingUseCaseSpy()

    private func viewModel(_ detail: PlaylistDetail? = nil, signedIn: Bool = true) -> PlaylistViewModel {
        if let detail { gateway.details[detail.playlist.id] = detail }
        let playlists = DefaultPlaylistUseCase(playlistGateway: gateway, sessionState: SessionState(server: signedIn ? .sample : nil))
        let shown = detail?.playlist ?? Playlist.numbered(1)[0]

        return PlaylistViewModel(playlist: shown, useCases: PlaylistUseCases(playlistUseCase: playlists, coverArtUseCase: art, playbackUseCase: playback, sessionUseCase: session, appRouting: routing))
    }

    private func png() -> Data? { UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData() }

    // PLST-7

    @Test func theInfoShowsOnlyWhatTheServerHas() async {
        let viewModel = viewModel(.numbered(3))

        #expect(viewModel.details == "weston · 3 songs · 2 hr 0 min")

        var bare = PlaylistDetail.numbered(1)
        bare.playlist.owner = nil
        bare.playlist.songCount = nil
        bare.playlist.duration = nil
        let other = self.viewModel(bare)
        _ = await other.handleAction(.lifecycle(.viewDidAppear))

        #expect(other.details == "1 song")
    }

    @Test func rowsAreInThePlaylistsOrderWithTheirPlace() async throws {
        let viewModel = viewModel(.numbered(3))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.rows.map(\.line.number) == ["1", "2", "3"])
        #expect(viewModel.rows.first?.line == AlbumRow(id: "t1", number: "1", title: "Track 1", artist: "Artist 1", duration: "3:20"))
    }

    @Test func aSongTwiceInAPlaylistIsTwoRows() async {
        let viewModel = viewModel(.numbered(2, repeatingTheFirst: true))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.rows.map(\.id) == [0, 1, 2])
        #expect(viewModel.rows.map(\.line.id) == ["t1", "t2", "t1"])
    }

    @Test func aTrackWithNoArtistShowsNone() async {
        var detail = PlaylistDetail.numbered(1)
        detail.tracks[0].artist = ""
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.rows.first?.line.artist == nil)
    }

    // PLST-8

    @Test func tappingATrackPlaysItAndQueuesTheRest() async throws {
        let viewModel = viewModel(.numbered(4))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.trackTapped(2))

        let played = try #require(playback.played.first)

        #expect(played.tracks.map(\.id) == ["t1", "t2", "t3", "t4"] && played.index == 2)
    }

    @Test func tappingTheSecondCopyOfARepeatedSongStartsThere() async throws {
        let viewModel = viewModel(.numbered(2, repeatingTheFirst: true))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.trackTapped(2))

        #expect(playback.played.first?.index == 2)
    }

    @Test func playStartsAtTheFirstTrack() async throws {
        let viewModel = viewModel(.numbered(3))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.playTapped)

        let played = try #require(playback.played.first)

        #expect(played.index == 0 && played.tracks.count == 3)
    }

    @Test func shufflePlaysEveryTrackOnce() async throws {
        let viewModel = viewModel(.numbered(3))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.shuffleTapped)

        let shuffled = try #require(playback.shuffled.first)

        #expect(shuffled.map(\.id) == ["t1", "t2", "t3"] && playback.played.isEmpty)
    }

    @Test func nothingPlaysBeforeTheTracksLoad() async {
        let viewModel = viewModel(.numbered(3))

        _ = await viewModel.handleAction(.playTapped)
        _ = await viewModel.handleAction(.shuffleTapped)
        _ = await viewModel.handleAction(.trackTapped(0))

        #expect(playback.played.isEmpty && playback.shuffled.isEmpty)
    }

    // PLST-9

    @Test func aStarredTrackShowsAHeart() async {
        var detail = PlaylistDetail.numbered(2)
        detail.tracks[1].isStarred = true
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.rows.map(\.line.isStarred) == [false, true])
    }

    // PLST-10

    @Test func aPlaylistWithNoTracksSaysSo() async {
        let viewModel = viewModel(PlaylistDetail(playlist: Playlist.numbered(1)[0], tracks: []))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty)
    }

    @Test func aFailureShowsItsMessageAndRetryLoadsAgain() async {
        gateway.detailError = .unreachable
        let viewModel = viewModel(.numbered(2))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .failed("Couldn't reach the server. Check your connection."))
        gateway.detailError = nil
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded)
    }

    @Test func signedOutTheScreenAsksToSignIn() async {
        let viewModel = viewModel(.numbered(2), signedIn: false)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .failed("Sign in to see this playlist."))
    }

    // PLST-11

    @Test(arguments: [ServerError.wrongCredentials, .failed(code: 41, message: "Token authentication not supported")])
    func aRejectedLoadGoesBackToSetup(error: ServerError) async {
        gateway.detailError = error
        let viewModel = viewModel(.numbered(2))

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1 && routing.steps == [.library])
    }

    // The cover is fetched at the size the screen shows it.

    @Test func theCoverIsFetchedOnceAtTheScreensSize() async {
        art.data = png()
        let viewModel = viewModel(.numbered(2))

        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 700))
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 700))

        #expect(art.requests.count == 1 && art.requests.first?.pixelSize == 700 && viewModel.cover != nil)
    }
}
