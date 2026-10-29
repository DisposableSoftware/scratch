import Foundation

/// The queue and the player (PLAY-1, PLAY-4, PLAY-5, PLAY-8), on screen and on the lock screen
/// (PLAY-6), through interruptions (PLAY-7).
protocol PlaybackUseCase {
    /// The queue and where playback is in it, for the screens that show it.
    var state: PlaybackState { get }

    /// Plays `tracks[index]` and queues the tracks after it.
    func play(_ tracks: [Track], startingAt index: Int)
    /// Queues every track once in a random order and plays the first of them (PLAY-9).
    func playShuffled(_ tracks: [Track])
    func togglePlayPause()
    func next()
    func previous()
    func seek(to seconds: TimeInterval)
    /// Unloads everything: the queue, the player and the lock screen.
    func stop()
}

final class DefaultPlaybackUseCase: PlaybackUseCase {
    /// Further into a track than this, Previous restarts it instead of going back.
    static let restartThreshold: TimeInterval = 3

    private let audioPlayer: AudioPlayerGateway
    private let nowPlaying: NowPlayingGateway
    private let transcoding: TranscodingUseCase
    /// Puts tracks in a random order; tests give one that isn't.
    private let shuffle: ([Track]) -> [Track]
    private let sessionState: SessionState
    private let playbackState: PlaybackState
    /// Whether an interruption paused playback that should come back when it ends.
    private var resumeAfterInterruption = false
    /// Whether the stream is catching up, so the lock screen's clock should stand still.
    private var buffering = false

    init(
        audioPlayer: AudioPlayerGateway,
        nowPlaying: NowPlayingGateway,
        transcoding: TranscodingUseCase,
        sessionState: SessionState,
        playbackState: PlaybackState,
        shuffle: @escaping ([Track]) -> [Track] = { $0.shuffled() }
    ) {
        self.audioPlayer = audioPlayer
        self.nowPlaying = nowPlaying
        self.transcoding = transcoding
        self.shuffle = shuffle
        self.sessionState = sessionState
        self.playbackState = playbackState
        audioPlayer.onEvent = { [weak self] event in self?.handle(event) }
        nowPlaying.onCommand = { [weak self] command in self?.handle(command) }
    }

    var state: PlaybackState { playbackState }

    func play(_ tracks: [Track], startingAt index: Int) {
        guard sessionState.server != nil, tracks.indices.contains(index) else { return }
        playbackState.queue = Array(tracks[index...])
        start(at: 0)
    }

    func playShuffled(_ tracks: [Track]) {
        guard sessionState.server != nil, !tracks.isEmpty else { return }
        playbackState.queue = shuffle(tracks)
        start(at: 0)
    }

    func togglePlayPause() {
        switch playbackState.status {
        case .playing, .loading:
            pause()
        case .paused:
            resume()
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
        publishNowPlaying()
    }

    func stop() {
        resumeAfterInterruption = false
        buffering = false
        audioPlayer.stop()
        playbackState.queue = []
        playbackState.currentIndex = nil
        playbackState.status = .stopped
        playbackState.elapsed = 0
        playbackState.duration = nil
        playbackState.quality = nil
        nowPlaying.update(nil)
    }

    private func pause() {
        resumeAfterInterruption = false
        audioPlayer.pause()
        playbackState.status = .paused
        publishNowPlaying()
    }

    private func resume() {
        resumeAfterInterruption = false
        audioPlayer.play()
        playbackState.status = .playing
        publishNowPlaying()
    }

    private func start(at index: Int) {
        guard let server = sessionState.server, playbackState.queue.indices.contains(index) else { return }
        let track = playbackState.queue[index]
        resumeAfterInterruption = false
        buffering = false
        playbackState.currentIndex = index
        playbackState.elapsed = 0
        playbackState.duration = track.duration.map(TimeInterval.init)
        playbackState.status = .loading
        // TRANS-3: the quality for the network this track starts on.
        let quality = transcoding.qualityForNextTrack()
        playbackState.quality = quality
        audioPlayer.load(track, server: server, quality: quality)
        publishNowPlaying()
    }

    /// PLAY-4: after the last track, stop at its start rather than unloading it.
    private func stopAtStartOfLastTrack() {
        resumeAfterInterruption = false
        audioPlayer.pause()
        audioPlayer.seek(to: 0)
        playbackState.elapsed = 0
        playbackState.status = .paused
        publishNowPlaying()
    }

    private func handle(_ event: AudioPlayerEvent) {
        switch event {
        case .ready(let duration):
            if let duration { playbackState.duration = duration }
            if playbackState.status == .loading { playbackState.status = .playing }
            publishNowPlaying()
        case .time(let seconds):
            // The lock screen moves its own clock along, so ticks aren't published.
            if playbackState.status == .playing { playbackState.elapsed = seconds }
        case .ended:
            next()
        case .failed:
            // PLAY-8: stop and say so; never move on by itself.
            resumeAfterInterruption = false
            audioPlayer.stop()
            playbackState.status = .failed
            publishNowPlaying()
        case .interrupted:
            // PLAY-7: AVPlayer has already stopped; remember whether to come back.
            let wasPlaying = playbackState.status == .playing || playbackState.status == .loading
            if wasPlaying { pause() }
            resumeAfterInterruption = wasPlaying
        case .interruptionEnded(let shouldResume):
            // Only what the interruption paused comes back: not a track that failed meanwhile.
            if shouldResume && resumeAfterInterruption && playbackState.status == .paused { resume() }
            resumeAfterInterruption = false
        case .outputLost:
            if playbackState.status == .playing || playbackState.status == .loading { pause() }
            resumeAfterInterruption = false
        case .buffering(let waiting):
            guard waiting != buffering else { return }
            buffering = waiting
            if waiting, playbackState.status == .playing { playbackState.elapsed = audioPlayer.currentTime }
            publishNowPlaying()
        }
    }

    private func handle(_ command: RemoteCommand) {
        switch command {
        case .play:
            if playbackState.status == .paused || playbackState.status == .failed { togglePlayPause() }
        case .pause:
            if playbackState.status == .playing || playbackState.status == .loading { pause() }
        case .togglePlayPause:
            togglePlayPause()
        case .next:
            next()
        case .previous:
            previous()
        case .seek(let seconds):
            seek(to: seconds)
        }
    }

    /// PLAY-6: the lock screen and Control Center show the current track.
    private func publishNowPlaying() {
        guard let track = playbackState.currentTrack else {
            nowPlaying.update(nil)
            return
        }
        nowPlaying.update(NowPlayingInfo(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: playbackState.duration,
            elapsed: playbackState.elapsed,
            isPlaying: playbackState.status == .playing && !buffering
        ))
    }
}
