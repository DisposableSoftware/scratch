import Foundation
import Testing
import UIKit
@testable import Scratch

private struct MixesUseCases: HasMixUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasTranscodingUseCase,
    HasDisplayUseCase, HasSessionUseCase, HasAppRoutingUseCase, HasCoordinator {
    let mixUseCase: MixUseCase
    let coverArtUseCase: CoverArtUseCase
    var playbackUseCase: PlaybackUseCase = PlaybackUseCaseMock()
    var displayUseCase: DisplayUseCase = DisplayUseCaseMock()
    var transcodingUseCase: TranscodingUseCase = TranscodingUseCaseMock()
    var sessionUseCase: SessionUseCase = SessionUseCaseMock()
    var appRouting: AppRoutingUseCase = AppRoutingUseCaseSpy()
    var coordinator: Coordinator = CoordinatorSpy()
}

@Suite(.timeLimit(.minutes(1)))
struct MixesViewModelTests {
    private let gateway = AlbumGatewayMock()
    private let model = MixModelGatewayMock()
    private let state = MixesState()
    private let art = CoverArtUseCaseMock()
    private let coordinator = CoordinatorSpy()
    private let session = SessionUseCaseMock()
    private let routing = AppRoutingUseCaseSpy()

    private var viewModel: MixesViewModel {
        let mixes = DefaultMixUseCase(albumGateway: gateway, modelGateway: model, sessionState: SessionState(server: .sample), mixesState: state)

        return MixesViewModel(useCases: MixesUseCases(mixUseCase: mixes, coverArtUseCase: art, sessionUseCase: session, appRouting: routing, coordinator: coordinator))
    }

    private func png() -> Data? { UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData() }

    // MIX-2, MIX-3

    @Test func showsTheMixesTheDeviceMade() async {
        gateway.starredTrackList = Track.numbered(3)
        let viewModel = viewModel

        #expect(viewModel.phase == .loading)

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded && viewModel.mixes.map(\.kind) == [.hearts] && !viewModel.isMaking)
    }

    @Test func nothingToMixSaysSo() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty && viewModel.mixes.isEmpty)
    }

    @Test func aServerErrorShowsItsMessageAndRetryTriesAgain() async {
        gateway.starredTracksError = .unreachable
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .failed("Couldn't reach the server. Check your connection."))
        gateway.starredTracksError = nil
        gateway.starredTrackList = Track.numbered(2)
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded && viewModel.mixes.count == 1)
    }

    // MIX-9

    @Test func comingBackToTheTabDoesNotMakeThemAgain() async {
        gateway.starredTrackList = Track.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(model.asked.count == 1)
    }

    @Test func aNewScreenStartsFromTheMixesTheStateKept() {
        state.mixes = [Mix(kind: .hearts, name: "Hearts", description: "", tracks: Track.numbered(2))]
        let viewModel = viewModel

        #expect(viewModel.phase == .loaded && viewModel.mixes.count == 1)
    }

    @Test func aFailureAfterSomeMixesLandedKeepsThemAndDoesntMakeThemAgainOnReturning() async {
        gateway.starredTrackList = Track.numbered(2)
        gateway.frequentError = .unreachable
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded && viewModel.mixes.map(\.kind) == [.hearts])
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(model.asked.count == 1)
    }

    // MIX-4

    @Test func aRefreshMakesThemAgainFromTheServersCurrentSongs() async {
        gateway.starredTrackList = Track.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.starredTrackList = Track.numbered(4)

        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.mixes.first?.tracks.count == 4 && viewModel.phase == .loaded)
    }

    @Test func aFailedRefreshKeepsTheMixesOnScreen() async {
        gateway.starredTrackList = Track.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.starredTracksError = .unreachable

        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.phase == .loaded && viewModel.mixes.count == 1)
    }

    // MIX-10

    @Test func tappingAMixPushesItsScreen() async {
        gateway.starredTrackList = Track.numbered(2)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.mixTapped(.hearts))

        guard case .push(let key, _) = coordinator.destinations.first else {
            Issue.record("expected a push, got \(coordinator.destinations)")
            return
        }

        #expect(key == "mix:hearts" && coordinator.destinations.count == 1)
    }

    @Test func tappingAMixThatIsntThereDoesNothing() async {
        _ = await viewModel.handleAction(.mixTapped(.onThisDay))

        #expect(coordinator.destinations.isEmpty)
    }

    // The card's cover is the first track's.

    @Test func coversAreFetchedOncePerCardAtItsSize() async {
        art.data = png()
        let viewModel = viewModel

        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 216))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 216))

        #expect(art.requests.count == 1 && viewModel.artwork["c1"] != nil)
    }

    // MIX-12

    @Test(arguments: [ServerError.wrongCredentials, .failed(code: 41, message: "Token authentication not supported")])
    func aRejectedRequestGoesBackToSetup(error: ServerError) async {
        gateway.starredTracksError = error
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1 && routing.steps == [.library])
    }
}
