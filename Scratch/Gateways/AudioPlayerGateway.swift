import AVFoundation
import Combine
import Foundation

/// Plays one track at a time from the server and reports what happens through `onEvent`.
protocol AudioPlayerGateway: AnyObject {
    var onEvent: ((AudioPlayerEvent) -> Void)? { get set }
    var currentTime: TimeInterval { get }

    /// Starts streaming the track; it plays as soon as it can.
    func load(_ track: Track, server: SavedServer)
    func play()
    func pause()
    func seek(to seconds: TimeInterval)
    /// Unloads the track.
    func stop()
}

final class AVPlayerAudioGateway: AudioPlayerGateway {
    var onEvent: ((AudioPlayerEvent) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var itemObservers: [AnyCancellable] = []

    init() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard time.seconds.isFinite else { return }
                self?.onEvent?(.time(time.seconds))
            }
        }
    }

    var currentTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    func load(_ track: Track, server: SavedServer) {
        itemObservers = []
        let request = SubsonicRequest(method: "stream", parameters: [URLQueryItem(name: "id", value: track.id)])
        guard let url = try? request.url(baseURL: server.account.baseURL, credentials: server.credentials) else {
            player.replaceCurrentItem(with: nil)
            onEvent?(.failed)
            return
        }
        let item = AVPlayerItem(url: url)
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] status in
                switch status {
                case .readyToPlay:
                    let duration = item?.duration.seconds
                    self?.onEvent?(.ready(duration: duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }))
                case .failed:
                    self?.onEvent?(.failed)
                default:
                    break
                }
            }
            .store(in: &itemObservers)
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.onEvent?(.ended) }
            .store(in: &itemObservers)
        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.onEvent?(.failed) }
            .store(in: &itemObservers)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: TimeInterval) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func stop() {
        itemObservers = []
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
