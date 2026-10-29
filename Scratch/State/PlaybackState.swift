import Combine
import Foundation

/// The queue and where playback is in it. PlaybackUseCase updates it; the now-playing bar,
/// the player and the lock screen read it.
final class PlaybackState: ObservableObject {
    @Published var queue: [Track] = []
    @Published var currentIndex: Int?
    @Published var status = PlaybackStatus.stopped
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval?

    var currentTrack: Track? {
        currentIndex.flatMap { queue.indices.contains($0) ? queue[$0] : nil }
    }
}
