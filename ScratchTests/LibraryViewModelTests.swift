import Foundation
import Testing
import UIKit
@testable import Scratch

private struct LibraryUseCases: HasLibraryUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasTranscodingUseCase,
    HasDisplayUseCase, HasSessionUseCase, HasAppRoutingUseCase, HasCoordinator {
    let libraryUseCase: LibraryUseCase
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
    var transcodingUseCase: TranscodingUseCase = TranscodingUseCaseMock()
    var displayUseCase: DisplayUseCase = DisplayUseCaseMock()
    var sessionUseCase: SessionUseCase = SessionUseCaseMock()
    var appRouting: AppRoutingUseCase = AppRoutingUseCaseSpy()
    var coordinator: Coordinator = CoordinatorSpy()
}

@Suite(.timeLimit(.minutes(1)))
struct LibraryViewModelTests {
    private let gateway = LibraryGatewayMock()
    private let art = CoverArtUseCaseMock()
    private let playback = PlaybackUseCaseMock()
    private let session = SessionUseCaseMock()
    private let routing = AppRoutingUseCaseSpy()

    private var viewModel: LibraryViewModel {
        let library = DefaultLibraryUseCase(libraryGateway: gateway, sessionState: SessionState(server: .sample), libraryState: LibraryState())
        return LibraryViewModel(useCases: LibraryUseCases(libraryUseCase: library, coverArtUseCase: art, playbackUseCase: playback, sessionUseCase: session, appRouting: routing))
    }

    @Test func showsTheFirstPageWithItsDetails() async {
        gateway.all = Track.numbered(3)
        let viewModel = viewModel

        #expect(viewModel.phase == .loading)

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.tracks == Track.numbered(3))
    }

    @Test func anEmptyLibrarySaysSo() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty)
    }

    @Test func aFailedLoadShowsWhyAndRetries() async {
        gateway.error = .unreachable
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }

        #expect(message.contains("Couldn't reach the server"))

        gateway.error = nil
        gateway.all = Track.numbered(2)
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded && viewModel.tracks.count == 2)
    }

    @Test func rowsNearTheEndLoadTheNextPage() async {
        gateway.all = Track.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.rowAppeared("t10"))

        #expect(viewModel.tracks.count == 100)
        _ = await viewModel.handleAction(.rowAppeared("t85"))

        #expect(viewModel.tracks.count == 150)
        #expect(gateway.requests.map(\.offset) == [0, 100])
    }

    @Test func aFailedNextPageKeepsTheListAndOffersRetry() async {
        gateway.all = Track.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .unreachable

        _ = await viewModel.handleAction(.rowAppeared("t99"))

        #expect(viewModel.phase == .loaded && viewModel.tracks.count == 100)
        #expect(viewModel.loadMoreError != nil)

        gateway.error = nil
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.tracks.count == 150 && viewModel.loadMoreError == nil)
    }

    @Test func artworkIsFetchedOncePerCoverAndSize() async {
        art.data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData()
        let viewModel = viewModel

        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 144))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 144))

        #expect(art.requests.count == 1)
        #expect(art.requests.first?.pixelSize == 144)
        #expect(viewModel.artwork["c1"] != nil)
    }

    @Test func aFailedCoverIsAskedForAgain() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 144))

        #expect(viewModel.artwork["c1"] == nil)

        art.data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData()
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 144))

        #expect(art.requests.count == 2)
        #expect(viewModel.artwork["c1"] != nil)
    }

    @Test func keepsOnlyTheMostRecentCovers() async {
        art.data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData()
        let viewModel = viewModel

        for index in 0...LibraryViewModel.artworkLimit {
            _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c\(index)", pixelSize: 144))
        }

        #expect(viewModel.artwork.count == LibraryViewModel.artworkLimit)
        #expect(viewModel.artwork["c0"] == nil)

        // The evicted cover is fetched again when its row comes back.
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c0", pixelSize: 144))

        #expect(viewModel.artwork["c0"] != nil)
    }

    @Test func overlappingFirstLoadsDontFlashEmpty() async {
        gateway.all = Track.numbered(3)
        let hold = gateway.holdNextRequest()
        let viewModel = viewModel

        let first = Task { await viewModel.handleAction(.lifecycle(.viewDidAppear)) }
        for await _ in hold.entered { break }
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loading)
        hold.release()
        _ = await first.value

        #expect(viewModel.phase == .loaded && viewModel.tracks.count == 3)
        #expect(gateway.requests.count == 1)
    }

    @Test func pullToRefreshReloadsFromTheFirstPageWithTheListStillShown() async {
        gateway.all = Track.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.rowAppeared("t99"))

        #expect(viewModel.tracks.count == 150)

        gateway.all = Track.numbered(4)
        let hold = gateway.holdNextRequest()
        let refresh = Task { await viewModel.handleAction(.refresh) }
        for await _ in hold.entered { break }

        #expect(viewModel.phase == .loaded && viewModel.tracks.count == 150)
        hold.release()
        _ = await refresh.value

        #expect(viewModel.tracks == Track.numbered(4))
        #expect(gateway.requests.last?.offset == 0)
    }

    @Test func pagingStartsOverAfterARefresh() async {
        gateway.all = Track.numbered(250)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.rowAppeared("t99"))
        _ = await viewModel.handleAction(.rowAppeared("t199"))

        #expect(viewModel.tracks.count == 250)

        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.tracks.count == 100)
        _ = await viewModel.handleAction(.rowAppeared("t99"))

        #expect(viewModel.tracks.count == 200)
    }

    @Test func anEmptyLibraryCanBeRefreshed() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty)

        gateway.all = Track.numbered(2)
        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.phase == .loaded && viewModel.tracks.count == 2)
    }

    @Test func aFailedRefreshSaysWhyWithRetry() async {
        gateway.all = Track.numbered(3)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .unreachable

        _ = await viewModel.handleAction(.refresh)

        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }

        #expect(message.contains("Couldn't reach the server"))

        gateway.error = nil
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded && viewModel.tracks.count == 3)
    }

    @Test func tappingATrackPlaysItFromTheLoadedList() async {
        gateway.all = Track.numbered(5)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.trackTapped("t2"))

        #expect(playback.played.count == 1)
        #expect(playback.played.first?.tracks == Track.numbered(5))
        #expect(playback.played.first?.index == 2)
    }

    @Test func theSettingsButtonOpensSettingsAsASheet() async {
        let coordinator = CoordinatorSpy()
        let library = DefaultLibraryUseCase(libraryGateway: gateway, sessionState: SessionState(server: .sample), libraryState: LibraryState())
        let viewModel = LibraryViewModel(useCases: LibraryUseCases(libraryUseCase: library, coverArtUseCase: art, playbackUseCase: playback, coordinator: coordinator))

        _ = await viewModel.handleAction(.settingsTapped)

        guard case .sheet = coordinator.destinations.last else {
            Issue.record("expected a sheet, got \(coordinator.destinations)")
            return
        }
    }

    // SRV-6

    @Test(arguments: [ServerError.wrongCredentials, .failed(code: 41, message: "Token authentication not supported")])
    func aRejectedFirstPageGoesBackToSetup(error: ServerError) async {
        gateway.error = error
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1)
        #expect(routing.steps == [.library])
    }

    @Test func aRejectedNextPageGoesBackToSetup() async {
        gateway.all = Track.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .wrongCredentials

        _ = await viewModel.handleAction(.rowAppeared("t99"))

        #expect(session.rejections == 1 && routing.steps == [.library])
        #expect(viewModel.loadMoreError == nil)
    }

    @Test func otherErrorsDontSignOut() async {
        gateway.error = .failed(code: 70, message: "Not found")
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 0 && routing.steps.isEmpty)
    }
}
