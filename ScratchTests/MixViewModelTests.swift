import Foundation
import Testing
import UIKit
@testable import Scratch

private struct MixUseCases: HasCoverArtUseCase, HasPlaybackUseCase {
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
}

@Suite(.timeLimit(.minutes(1)))
struct MixViewModelTests {
    private let art = CoverArtUseCaseMock()
    private let playback = PlaybackUseCaseMock()

    private func viewModel(_ count: Int = 4) -> MixViewModel {
        var tracks = Track.numbered(count)

        if count > 1 { tracks[1].isStarred = true }

        return MixViewModel(mix: Mix(kind: .hearts, name: "Late night", description: "Slow ones.", tracks: tracks), useCases: MixUseCases(coverArtUseCase: art, playbackUseCase: playback))
    }

    // MIX-10

    @Test func rowsAreInTheMixsOrderWithTheirPlaceAndHearts() {
        let viewModel = viewModel()

        #expect(viewModel.rows.map(\.line.number) == ["1", "2", "3", "4"])
        #expect(viewModel.rows.map(\.line.isStarred) == [false, true, false, false])
        #expect(viewModel.rows.first?.line.title == "Song 0")
    }

    // MIX-11

    @Test func tappingATrackPlaysItAndQueuesTheRest() async throws {
        let viewModel = viewModel()

        _ = await viewModel.handleAction(.trackTapped(2))

        let played = try #require(playback.played.first)

        #expect(played.tracks.map(\.id) == ["t0", "t1", "t2", "t3"] && played.index == 2)
    }

    @Test func playStartsAtTheFirstTrack() async throws {
        let viewModel = viewModel()

        _ = await viewModel.handleAction(.playTapped)

        #expect(playback.played.first?.index == 0 && playback.played.first?.tracks.count == 4)
    }

    @Test func shufflePlaysEveryTrackOnce() async throws {
        let viewModel = viewModel()

        _ = await viewModel.handleAction(.shuffleTapped)

        #expect(playback.shuffled.first?.count == 4 && playback.played.isEmpty)
    }

    @Test func aTapOutsideTheMixDoesNothing() async {
        let viewModel = viewModel()

        _ = await viewModel.handleAction(.trackTapped(9))

        #expect(playback.played.isEmpty)
    }

    @Test func theCoverIsTheFirstTracksAtTheScreensSize() async {
        art.data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData()
        let viewModel = viewModel()

        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 700))

        #expect(art.requests.first?.id == "c0" && art.requests.first?.pixelSize == 700 && viewModel.cover != nil)
    }
}
