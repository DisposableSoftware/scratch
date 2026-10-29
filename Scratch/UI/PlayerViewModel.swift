import Combine
import SwiftUI
import UIKit

enum PlayerAction: Equatable {
    case barTapped
    case playPause
    case next
    case previous
    /// The scrubber moved; only the shown position follows until it's let go.
    case scrubbed(TimeInterval)
    case scrubEnded
    /// The player went away mid-drag: drop the drag without seeking.
    case scrubCancelled
    case artworkNeeded(pixelSize: Int)
}

/// The now-playing bar and the player (PLAY-2, PLAY-3, PLAY-8). Both show the same playback, so
/// they share this ViewModel; it mirrors PlaybackState as it changes.
final class PlayerViewModel: RoutingViewModel {
    typealias UseCases = HasPlaybackUseCase & HasCoverArtUseCase & HasCoordinator

    enum Route: NavigationRoute {
        case player

        func destination(context: PlayerViewModel) -> NavigationDestination {
            .sheet(AnyView(PlayerView(viewModel: context)))
        }
    }

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    @Published private(set) var track: Track?
    @Published private(set) var status = PlaybackStatus.stopped
    @Published private(set) var duration: TimeInterval?
    /// What was asked of the server for this track (TRANS-6).
    @Published private(set) var quality: StreamQuality?
    /// Where the scrubber and the times show, which follows playback except while scrubbing.
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var isScrubbing = false
    /// The current track's cover, by pixel size.
    @Published private(set) var artwork: [Int: UIImage] = [:]

    private var requestedArtwork: Set<Int> = []

    init(useCases: UseCases) {
        self.useCases = useCases
        let state = useCases.playbackUseCase.state
        state.$queue.combineLatest(state.$currentIndex)
            .map { queue, index in index.flatMap { queue.indices.contains($0) ? queue[$0] : nil } }
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] _ in
                // A drag on the previous track's scrubber doesn't carry over to this one.
                self?.isScrubbing = false
                self?.artwork = [:]
                self?.requestedArtwork = []
            })
            .assign(to: &$track)
        state.$status.assign(to: &$status)
        state.$duration.assign(to: &$duration)
        state.$quality.assign(to: &$quality)
        state.$elapsed.combineLatest($isScrubbing)
            .filter { !$0.1 }
            .map(\.0)
            .assign(to: &$position)
    }

    var isPlaying: Bool { status == .playing || status == .loading }

    func handleAction(_ action: PlayerAction) async -> SideEffect {
        let playback = useCases.playbackUseCase
        switch action {
        case .barTapped:
            await navigateTo(.player)
        case .playPause:
            playback.togglePlayPause()
        case .next:
            playback.next()
        case .previous:
            playback.previous()
        case .scrubbed(let seconds):
            isScrubbing = true
            position = seconds
        case .scrubEnded:
            guard isScrubbing else { break }
            playback.seek(to: position)
            isScrubbing = false
        case .scrubCancelled:
            isScrubbing = false
            position = playback.state.elapsed
        case .artworkNeeded(let pixelSize):
            await loadArtwork(pixelSize: pixelSize)
        }
        return .none
    }

    private func loadArtwork(pixelSize: Int) async {
        guard let id = track?.coverArtID, !requestedArtwork.contains(pixelSize) else { return }
        requestedArtwork.insert(pixelSize)
        guard let data = await useCases.coverArtUseCase.coverArt(id: id, pixelSize: pixelSize),
              let image = await UIImage(data: data)?.byPreparingForDisplay(),
              track?.coverArtID == id
        else {
            requestedArtwork.remove(pixelSize)
            return
        }
        artwork[pixelSize] = image
    }
}
