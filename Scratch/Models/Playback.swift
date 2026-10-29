import Foundation

/// Where playback is.
enum PlaybackStatus: Equatable {
    /// Nothing loaded.
    case stopped

    /// A track is loading and will play when it can.
    case loading
    case playing
    case paused

    /// The current track couldn't be loaded or played (PLAY-8).
    case failed
}

/// What the audio player reports.
enum AudioPlayerEvent: Equatable {
    /// The track can play; its duration if the stream says.
    case ready(duration: TimeInterval?)
    case time(TimeInterval)
    case ended
    case failed

    /// Another app or a call took the audio (PLAY-7).
    case interrupted
    case interruptionEnded(shouldResume: Bool)

    /// The headphones or Bluetooth output went away (PLAY-7).
    case outputLost

    /// Playback is waiting for the stream to catch up, or has caught up.
    case buffering(Bool)
}

/// What the lock screen and Control Center show (PLAY-6).
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval?
    var elapsed: TimeInterval
    var isPlaying: Bool
}

/// What the lock screen, Control Center and headphone buttons ask for (PLAY-6).
enum RemoteCommand: Equatable {
    case play
    case pause
    case togglePlayPause
    case next
    case previous
    case seek(TimeInterval)
}
