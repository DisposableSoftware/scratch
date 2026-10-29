import Foundation
import Testing
import UIKit
@testable import Scratch

private struct PlaylistsUseCases: HasPlaylistUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasTranscodingUseCase,
    HasDisplayUseCase, HasSessionUseCase, HasAppRoutingUseCase, HasCoordinator {
    let playlistUseCase: PlaylistUseCase
    let coverArtUseCase: CoverArtUseCase
    var playbackUseCase: PlaybackUseCase = PlaybackUseCaseMock()
    var displayUseCase: DisplayUseCase = DisplayUseCaseMock()
    var transcodingUseCase: TranscodingUseCase = TranscodingUseCaseMock()
    var sessionUseCase: SessionUseCase = SessionUseCaseMock()
    var appRouting: AppRoutingUseCase = AppRoutingUseCaseSpy()
    var coordinator: Coordinator = CoordinatorSpy()
}

@Suite(.timeLimit(.minutes(1)))
struct PlaylistsViewModelTests {
    private let gateway = PlaylistGatewayMock()
    private let art = CoverArtUseCaseMock()
    private let coordinator = CoordinatorSpy()
    private let session = SessionUseCaseMock()
    private let routing = AppRoutingUseCaseSpy()
    private let display = DisplayUseCaseMock()

    private var viewModel: PlaylistsViewModel {
        let playlists = DefaultPlaylistUseCase(playlistGateway: gateway, sessionState: SessionState(server: .sample))
        return PlaylistsViewModel(useCases: PlaylistsUseCases(
            playlistUseCase: playlists, coverArtUseCase: art, displayUseCase: display, sessionUseCase: session, appRouting: routing, coordinator: coordinator
        ))
    }

    private func png() -> Data? { UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData() }

    // PLST-1, PLST-3

    @Test func showsThePlaylists() async {
        gateway.all = Playlist.numbered(3)
        let viewModel = viewModel

        #expect(viewModel.phase == .loading)

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.playlists == Playlist.numbered(3))
    }

    @Test func aServerWithNoPlaylistsSaysSo() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty)
    }

    @Test func aFailureShowsItsMessageAndRetryLoadsAgain() async {
        gateway.error = .unreachable
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .failed("Couldn't reach the server. Check your connection."))
        gateway.error = nil
        gateway.all = Playlist.numbered(2)
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded && viewModel.playlists.count == 2)
    }

    @Test func appearingAgainDoesNotReload() async {
        gateway.all = Playlist.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(gateway.requests == 1)
    }

    // PLST-2

    @Test func theGridFollowsTheAlbumsPerRowSetting() async {
        let viewModel = viewModel

        #expect(viewModel.columns == 2)
        display.state.albumsPerRow = 4

        #expect(viewModel.columns == 4)
    }

    // PLST-4

    @Test func aRefreshKeepsTheGridOnScreenAndReplacesIt() async {
        gateway.all = Playlist.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.all = Playlist.numbered(3)

        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.phase == .loaded && viewModel.playlists.count == 3 && gateway.requests == 2)
    }

    // PLST-5

    @Test func coversAreFetchedOncePerPlaylistAtTheCellsSize() async {
        art.data = png()
        let viewModel = viewModel

        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))

        #expect(art.requests.count == 1 && art.requests.first?.pixelSize == 360)
        #expect(viewModel.artwork["c1"] != nil)
    }

    // PLST-6

    @Test func tappingAPlaylistPushesItsScreen() async {
        gateway.all = Playlist.numbered(3)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.playlistTapped("p1"))

        guard case .push(let key, _) = coordinator.destinations.first else {
            Issue.record("expected a push, got \(coordinator.destinations)")
            return
        }

        #expect(key == "playlist:p1" && coordinator.destinations.count == 1)
    }

    @Test func tappingAPlaylistThatIsntThereDoesNothing() async {
        _ = await viewModel.handleAction(.playlistTapped("nope"))

        #expect(coordinator.destinations.isEmpty)
    }

    // PLST-11

    @Test(arguments: [ServerError.wrongCredentials, .failed(code: 41, message: "Token authentication not supported")])
    func aRejectedLoadGoesBackToSetup(error: ServerError) async {
        gateway.error = error
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1 && routing.steps == [.library])
        #expect(viewModel.phase == .loading)
    }

    @Test func aRejectedRefreshGoesBackToSetup() async {
        gateway.all = Playlist.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .wrongCredentials

        _ = await viewModel.handleAction(.refresh)

        #expect(session.rejections == 1 && routing.steps == [.library])
    }
}
