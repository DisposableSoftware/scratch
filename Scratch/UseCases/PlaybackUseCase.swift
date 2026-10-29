import Foundation

/// The queue and the player (PLAY-1, PLAY-4, PLAY-5, PLAY-8).
protocol PlaybackUseCase {
    /// The queue and where playback is in it, for the screens that show it.
    var state: PlaybackState { get }

    /// Plays `tracks[index]` and queues the tracks after it.
    func play(_ tracks: [Track], startingAt index: Int)
    func togglePlayPause()
    func next()
    func previous()
    func seek(to seconds: TimeInterval)
}

final class DefaultPlaybackUseCase: PlaybackUseCase {
    /// Further into a track than this, Previous restarts it instead of going back.
    static let restartThreshold: TimeInterval = 3

    private let audioPlayer: AudioPlayerGateway
    private let sessionState: SessionState
    private let playbackState: PlaybackState

    init(audioPlayer: AudioPlayerGateway, sessionState: SessionState, playbackState: PlaybackState) {
        self.audioPlayer = audioPlayer
        self.sessionState = sessionState
        self.playbackState = playbackState
        audioPlayer.onEvent = { [weak self] event in self?.handle(event) }
    }

    var state: PlaybackState { playbackState }

    func play(_ tracks: [Track], startingAt index: Int) {
        guard sessionState.server != nil, tracks.indices.contains(index) else { return }
        playbackState.queue = Array(tracks[index...])
        start(at: 0)
    }

    func togglePlayPause() {
        switch playbackState.status {
        case .playing, .loading:
            audioPlayer.pause()
            playbackState.status = .paused
        case .paused:
            audioPlayer.play()
            playbackState.status = .playing
        case .failed:
            if let index = playbackState.currentIndex { start(at: index) }
        case .stopped:
            break
        }
    }

    func next() {
        guard let index = playbackState.currentIndex else { return }
        if index + 1 < playbackState.queue.count {
            start(at: index + 1)
        } else if playbackState.status != .failed {
            stopAtStartOfLastTrack()
        }
    }

    func previous() {
        guard let index = playbackState.currentIndex else { return }
        // The state's elapsed time, not the player's: a seek lands asynchronously, so a second
        // press straight after a restart would otherwise restart again.
        if index > 0, playbackState.elapsed <= Self.restartThreshold || playbackState.status == .failed {
            start(at: index - 1)
        } else if playbackState.status == .failed {
            start(at: index)
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: TimeInterval) {
        guard playbackState.currentIndex != nil, playbackState.status != .failed else { return }
        audioPlayer.seek(to: seconds)
        playbackState.elapsed = seconds
    }

    private func start(at index: Int) {
        guard let server = sessionState.server, playbackState.queue.indices.contains(index) else { return }
        let track = playbackState.queue[index]
        playbackState.currentIndex = index
        playbackState.elapsed = 0
        playbackState.duration = track.duration.map(TimeInterval.init)
        playbackState.status = .loading
        audioPlayer.load(track, server: server)
    }

    /// PLAY-4: after the last track, stop at its start rather than unloading it.
    private func stopAtStartOfLastTrack() {
        audioPlayer.pause()
        audioPlayer.seek(to: 0)
        playbackState.elapsed = 0
        playbackState.status = .paused
    }

    private func handle(_ event: AudioPlayerEvent) {
        switch event {
        case .ready(let duration):
            if let duration { playbackState.duration = duration }
            if playbackState.status == .loading { playbackState.status = .playing }
        case .time(let seconds):
            if playbackState.status == .playing { playbackState.elapsed = seconds }
        case .ended:
            next()
        case .failed:
            // PLAY-8: stop and say so; never move on by itself.
            audioPlayer.stop()
            playbackState.status = .failed
        }
    }
}
