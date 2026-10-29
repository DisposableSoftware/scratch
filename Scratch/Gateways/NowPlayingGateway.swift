import Foundation
import MediaPlayer

/// The lock screen, Control Center and headphone buttons (PLAY-6).
protocol NowPlayingGateway: AnyObject {
    var onCommand: ((RemoteCommand) -> Void)? { get set }

    /// Shows the track, or clears it with nil.
    func update(_ info: NowPlayingInfo?)
}

final class MPNowPlayingGateway: NowPlayingGateway {
    var onCommand: ((RemoteCommand) -> Void)?

    init() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.send(.play) ?? .commandFailed }
        center.pauseCommand.addTarget { [weak self] _ in self?.send(.pause) ?? .commandFailed }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.send(.togglePlayPause) ?? .commandFailed }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.send(.next) ?? .commandFailed }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.send(.previous) ?? .commandFailed }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }

            return self?.send(.seek(event.positionTime)) ?? .commandFailed
        }
    }

    func update(_ info: NowPlayingInfo?) {
        guard let info else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped

            return
        }

        var values: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyAlbumTitle: info.album,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.elapsed,
            // The system moves the elapsed time along itself while the rate is 1.
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let duration = info.duration {
            values[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = values
        MPNowPlayingInfoCenter.default().playbackState = info.isPlaying ? .playing : .paused
    }

    private func send(_ command: RemoteCommand) -> MPRemoteCommandHandlerStatus {
        guard let onCommand else { return .noActionableNowPlayingItem }

        onCommand(command)

        return .success
    }
}
