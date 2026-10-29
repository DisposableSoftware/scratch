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

    private var sessionObservers: [AnyCancellable] = []

    init() {
        // Playback carries on in the background and with the screen locked (PLAY-6).
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        observeSession()
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

    /// Interruptions and lost outputs, as events (PLAY-7). AVPlayer pauses itself in both cases;
    /// the use case decides what happens next.
    private func observeSession() {
        let center = NotificationCenter.default
        // iOS 27: an interruption is the system deactivating the session, and the system says
        // separately whether playback should come back.
        center.publisher(for: AVAudioSession.didBecomeInactiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                // A lost route arrives as outputLost from the route-change notification instead.
                guard let context = note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
                      context.source == .system,
                      context.interruptionContext?.reason != .routeDisconnected
                else { return }
                self?.onEvent?(.interrupted)
            }
            .store(in: &sessionObservers)
        center.publisher(for: AVAudioSession.resumptionRecommendationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let context = note.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext
                self?.onEvent?(.interruptionEnded(shouldResume: context?.recommendation == .shouldResume))
            }
            .store(in: &sessionObservers)
        center.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
                else { return }
                self?.onEvent?(.outputLost)
            }
            .store(in: &sessionObservers)
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .waitingToPlayAtSpecifiedRate: self?.onEvent?(.buffering(true))
                case .playing: self?.onEvent?(.buffering(false))
                default: break
                }
            }
            .store(in: &sessionObservers)
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
        try? AVAudioSession.sharedInstance().setActive(true)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: TimeInterval) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    /// Also hands the audio back, so another app can carry on.
    func stop() {
        itemObservers = []
        player.pause()
        player.replaceCurrentItem(with: nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
