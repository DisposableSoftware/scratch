import Foundation
import Testing
import UIKit
@testable import Scratch

private struct PlayerUseCases: HasPlaybackUseCase, HasCoverArtUseCase, HasCoordinator {
    let playbackUseCase: PlaybackUseCase
    let coverArtUseCase: CoverArtUseCase
    let coordinator: Coordinator
}

@Suite(.timeLimit(.minutes(1)))

struct PlayerViewModelTests {
    private let player = AudioPlayerGatewayMock()
    private let art = CoverArtUseCaseMock()
    private let coordinator = CoordinatorSpy()
    private let playback: DefaultPlaybackUseCase
    private let viewModel: PlayerViewModel

    init() {
        playback = DefaultPlaybackUseCase(audioPlayer: player, nowPlaying: NowPlayingGatewayMock(), transcoding: TranscodingUseCaseMock(), sessionState: SessionState(server: .sample), playbackState: PlaybackState())
        viewModel = PlayerViewModel(useCases: PlayerUseCases(playbackUseCase: playback, coverArtUseCase: art, coordinator: coordinator))
    }

    @Test func nothingShowsUntilATrackIsLoaded() {
        #expect(viewModel.track == nil && viewModel.status == .stopped)
    }

    @Test func mirrorsWhatIsPlaying() {
        playback.play(Track.numbered(3), startingAt: 1)
        player.send(.ready(duration: 180))
        player.send(.time(42))

        #expect(viewModel.track?.id == "t1")
        #expect(viewModel.status == .playing && viewModel.isPlaying)
        #expect(viewModel.duration == 180 && viewModel.position == 42)
    }

    @Test func theControlsDriveThePlayer() async {
        playback.play(Track.numbered(3), startingAt: 0)
        player.send(.ready(duration: nil))

        _ = await viewModel.handleAction(.playPause)

        #expect(viewModel.status == .paused)
        _ = await viewModel.handleAction(.next)

        #expect(viewModel.track?.id == "t1")
        _ = await viewModel.handleAction(.previous)

        #expect(viewModel.track?.id == "t0")
    }

    @Test func scrubbingMovesOnlyTheShownPositionUntilLetGo() async {
        playback.play(Track.numbered(1), startingAt: 0)
        player.send(.ready(duration: 300))
        player.send(.time(10))

        _ = await viewModel.handleAction(.scrubbed(120))
        player.send(.time(11))

        #expect(viewModel.position == 120)
        #expect(!player.calls.contains(.seek(120)))

        _ = await viewModel.handleAction(.scrubEnded)

        #expect(player.calls.last == .seek(120))
        #expect(viewModel.position == 120 && !viewModel.isScrubbing)
    }

    @Test func aFailedStreamShows() {
        playback.play(Track.numbered(1), startingAt: 0)
        player.send(.failed)

        #expect(viewModel.status == .failed && viewModel.track?.id == "t0")
    }

    @Test func tappingTheBarOpensThePlayerAsASheet() async {
        playback.play(Track.numbered(1), startingAt: 0)
        _ = await viewModel.handleAction(.barTapped)
        guard case .sheet = coordinator.destinations.last else {
            Issue.record("expected a sheet, got \(coordinator.destinations)")
            return
        }
    }

    @Test func coverArtFollowsTheTrack() async {
        art.data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData()
        playback.play(Track.numbered(2), startingAt: 0)
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 120))

        #expect(viewModel.artwork[120] != nil && art.requests.last?.id == "c0")

        playback.next()

        #expect(viewModel.artwork.isEmpty)
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 120))

        #expect(art.requests.last?.id == "c1")
    }

    @Test func aTrackChangeMidScrubDropsTheDrag() async {
        playback.play(Track.numbered(2), startingAt: 0)
        player.send(.ready(duration: 300))
        _ = await viewModel.handleAction(.scrubbed(200))

        player.send(.ended)
        _ = await viewModel.handleAction(.scrubEnded)

        #expect(viewModel.track?.id == "t1" && !viewModel.isScrubbing)
        #expect(!player.calls.contains(.seek(200)))
    }

    @Test func lettingGoWithoutDraggingDoesntSeek() async {
        playback.play(Track.numbered(1), startingAt: 0)
        player.send(.ready(duration: 300))
        _ = await viewModel.handleAction(.scrubEnded)

        #expect(!player.calls.contains { if case .seek = $0 { true } else { false } })
    }

    @Test func closingThePlayerMidDragDropsIt() async {
        playback.play(Track.numbered(1), startingAt: 0)
        player.send(.ready(duration: 300))
        player.send(.time(10))
        _ = await viewModel.handleAction(.scrubbed(200))

        _ = await viewModel.handleAction(.scrubCancelled)
        player.send(.time(11))

        #expect(!viewModel.isScrubbing && viewModel.position == 11)
    }

    @Test func showsTheQualityAskedForTheTrack() {
        playback.play(Track.numbered(2), startingAt: 0)

        #expect(viewModel.quality == TranscodingSettings.defaults.wifi)
        player.send(.failed)

        #expect(viewModel.quality == TranscodingSettings.defaults.wifi)
    }

    @Test(arguments: [
        (StreamQuality(format: .mp3, maxBitRate: 192), "MP3 · 192 kbps"),
        (StreamQuality(format: .aac, maxBitRate: nil), "AAC"),
        (StreamQuality(format: .original, maxBitRate: nil), "Original"),
        (StreamQuality(format: .original, maxBitRate: 96), "Original"),
    ])

    func qualityLabels(quality: StreamQuality, expected: String) {
        #expect(quality.label == expected)
    }
}
