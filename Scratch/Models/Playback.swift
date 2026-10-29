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
}
