import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Scratch

/// Renders screens to PNGs for a look by eye. Skipped unless scripts/manual/snapshots.sh passes a
/// directory in. ImageRenderer draws some controls (Slider, Button chrome) as placeholders.
@Suite(.serialized, .enabled(if: Snapshots.directory != nil))
struct SnapshotTests {
    private struct UseCases: HasPlaybackUseCase, HasCoverArtUseCase, HasCoordinator {
        let playbackUseCase: PlaybackUseCase
        let coverArtUseCase: CoverArtUseCase
        let coordinator: Coordinator
    }

    private func viewModel(failed: Bool) async -> PlayerViewModel {
        let player = AudioPlayerGatewayMock()
        let playback = DefaultPlaybackUseCase(audioPlayer: player, nowPlaying: NowPlayingGatewayMock(), sessionState: SessionState(server: .sample), playbackState: PlaybackState())
        let art = CoverArtUseCaseMock()
        art.data = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
        }.pngData()
        let viewModel = PlayerViewModel(useCases: UseCases(playbackUseCase: playback, coverArtUseCase: art, coordinator: CoordinatorSpy()))
        playback.play([Track(id: "1", title: "You gave away", artist: "Mars Argo", album: "Live at Bedrock Studios", duration: 224, coverArtID: "c")], startingAt: 0)
        player.send(failed ? .failed : .ready(duration: 224))
        player.send(.time(83))
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 120))
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 900))
        return viewModel
    }

    private func write<V: View>(_ view: V, size: CGSize, name: String) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).background(Color(.systemBackground)))
        renderer.scale = 3
        let data = try #require(renderer.uiImage?.pngData())
        try data.write(to: URL(fileURLWithPath: try #require(Snapshots.directory)).appending(path: name))
    }

    @Test func nowPlayingBarAndPlayer() async throws {
        for failed in [false, true] {
            let viewModel = await viewModel(failed: failed)
            let suffix = failed ? "failed" : "playing"
            try write(NowPlayingBar(viewModel: viewModel), size: CGSize(width: 402, height: 60), name: "play2-bar-\(suffix).png")
            try write(PlayerView(viewModel: viewModel), size: CGSize(width: 402, height: 820), name: "play3-player-\(suffix).png")
        }
    }
}

nonisolated enum Snapshots {
    static var directory: String? { ProcessInfo.processInfo.environment["SCRATCH_SNAPSHOTS"] }
}
