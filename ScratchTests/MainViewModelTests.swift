import Foundation
import Testing
@testable import Scratch

private struct MainUseCases: HasMixUseCase, HasPlaybackUseCase, HasCoverArtUseCase, HasTranscodingUseCase, HasCoordinator {
    let mixUseCase: MixUseCase
    var playbackUseCase: PlaybackUseCase = PlaybackUseCaseMock()
    var coverArtUseCase: CoverArtUseCase = CoverArtUseCaseMock()
    var transcodingUseCase: TranscodingUseCase = TranscodingUseCaseMock()
    var coordinator: Coordinator = CoordinatorSpy()
}

@Suite(.timeLimit(.minutes(1)))
struct MainViewModelTests {
    private let model = MixModelGatewayMock()
    private let state = MixesState()

    private var viewModel: MainViewModel {
        let mixes = DefaultMixUseCase(albumGateway: AlbumGatewayMock(), modelGateway: model, sessionState: SessionState(server: .sample), mixesState: state)
        let useCases = MainUseCases(mixUseCase: mixes)

        return MainViewModel(player: PlayerViewModel(useCases: useCases), useCases: useCases)
    }

    // MIX-1

    @Test func theMeTabIsHiddenUntilTheModelIsKnownToBeAvailable() {
        #expect(!viewModel.showsMe)
    }

    @Test func appearingChecksTheModelAndShowsTheTab() async {
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.showsMe)
    }

    @Test func theTabComesAndGoesWithTheModel() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        model.isAvailable = false
        _ = await viewModel.handleAction(.appBecameActive)

        #expect(!viewModel.showsMe)
        model.isAvailable = true
        _ = await viewModel.handleAction(.appBecameActive)

        #expect(viewModel.showsMe)
    }

    @Test func aModelAlreadyKnownToBeThereShowsTheTabAtOnce() {
        state.isModelAvailable = true

        #expect(viewModel.showsMe)
    }

    // PLAY-2

    @Test func theNowPlayingBarFollowsTheCurrentTrack() async {
        let playback = PlaybackUseCaseMock()
        let mixes = DefaultMixUseCase(albumGateway: AlbumGatewayMock(), modelGateway: model, sessionState: SessionState(server: .sample), mixesState: state)
        let useCases = MainUseCases(mixUseCase: mixes, playbackUseCase: playback)
        let viewModel = MainViewModel(player: PlayerViewModel(useCases: useCases), useCases: useCases)

        #expect(!viewModel.hasTrack)
        playback.state.queue = Track.numbered(1)
        playback.state.currentIndex = 0
        await Task.yield()

        #expect(viewModel.hasTrack)
    }
}
