import AVFoundation
import MediaPlayer
import Testing
@testable import Scratch

/// The gateways onto system services, checked against those services in the test host.
@Suite(.serialized)
struct SystemGatewayTests {
    @Test func theAudioSessionIsSetUpForBackgroundPlayback() {
        _ = AVPlayerAudioGateway()
        #expect(AVAudioSession.sharedInstance().category == .playback)
    }

    @Test func theLockScreenGetsTheTrackAndClearsIt() throws {
        let gateway = MPNowPlayingGateway()
        gateway.update(NowPlayingInfo(title: "You gave away", artist: "Mars Argo", album: "Live", duration: 224, elapsed: 83, isPlaying: true))

        let info = try #require(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        #expect(info[MPMediaItemPropertyTitle] as? String == "You gave away")
        #expect(info[MPMediaItemPropertyArtist] as? String == "Mars Argo")
        #expect(info[MPMediaItemPropertyAlbumTitle] as? String == "Live")
        #expect(info[MPMediaItemPropertyPlaybackDuration] as? Double == 224)
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double == 83)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)

        gateway.update(nil)
        #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo == nil)
    }

    @Test func theLockScreenCommandsAreWiredUp() {
        let center = MPRemoteCommandCenter.shared()
        _ = MPNowPlayingGateway()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.nextTrackCommand, center.previousTrackCommand, center.changePlaybackPositionCommand] {
            #expect(command.isEnabled)
        }
    }

    @Test func aLostOutputIsReported() async throws {
        let gateway = AVPlayerAudioGateway()
        var events: [AudioPlayerEvent] = []
        gateway.onEvent = { events.append($0) }

        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
        ])
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
        ])
        // The gateway hops to the main queue; awaiting lets that run.
        try await Task.sleep(for: .milliseconds(200))

        #expect(events == [.outputLost], "got \(events)")
    }

    @Test func theSimulatorIsNotOnCellular() {
        // The simulator shares the Mac's network, which is never cellular, so Wi-Fi quality applies.
        #expect(PathMonitorNetworkGateway().currentNetwork == .wifi)
    }
}
