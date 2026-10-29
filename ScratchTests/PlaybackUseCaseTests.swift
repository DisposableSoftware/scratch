import Foundation
import Testing
@testable import Scratch

struct PlaybackUseCaseTests {
    private let player = AudioPlayerGatewayMock()
    private let lockScreen = NowPlayingGatewayMock()
    private let transcoding = TranscodingUseCaseMock()
    private let state = PlaybackState()
    private let tracks = Track.numbered(4)
    private func useCase(signedIn: Bool = true, shuffle: (([Track]) -> [Track])? = nil) -> DefaultPlaybackUseCase {
        let session = SessionState(server: signedIn ? .sample : nil)
        guard let shuffle else {
            return DefaultPlaybackUseCase(audioPlayer: player, nowPlaying: lockScreen, transcoding: transcoding, sessionState: session, playbackState: state)
        }
        return DefaultPlaybackUseCase(audioPlayer: player, nowPlaying: lockScreen, transcoding: transcoding, sessionState: session, playbackState: state, shuffle: shuffle)
    }

    @Test func playsTheTappedTrackAndQueuesTheRest() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 1)

        #expect(state.queue.map(\.id) == ["t1", "t2", "t3"])
        #expect(state.currentTrack?.id == "t1")
        #expect(state.status == .loading)
        #expect(player.loads == ["t1"])

        player.send(.ready(duration: 200))
        #expect(state.status == .playing && state.duration == 200)
    }

    @Test func aTrackThatEndsMovesToTheNext() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 2)
        player.send(.ready(duration: nil))

        player.send(.ended)

        #expect(state.currentTrack?.id == "t3")
        #expect(player.loads == ["t2", "t3"])
    }

    @Test func afterTheLastTrackPlaybackStopsAtItsStart() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 3)
        player.send(.ready(duration: nil))
        player.send(.time(150))

        player.send(.ended)

        #expect(state.currentTrack?.id == "t3")
        #expect(state.status == .paused && state.elapsed == 0)
        #expect(player.calls.suffix(2) == [.pause, .seek(0)])
        #expect(player.loads == ["t3"])
    }

    @Test func previousRestartsATrackMoreThanThreeSecondsIn() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        useCase.next()
        player.send(.ready(duration: nil))
        player.send(.time(3.5))

        useCase.previous()

        #expect(state.currentTrack?.id == "t1")
        #expect(player.calls.last == .seek(0))
    }

    @Test func previousGoesBackWithinTheFirstThreeSeconds() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        useCase.next()
        player.send(.ready(duration: nil))
        player.send(.time(3))

        useCase.previous()

        #expect(state.currentTrack?.id == "t0")
        #expect(player.loads == ["t0", "t1", "t0"])
    }

    @Test func previousOnTheFirstQueuedTrackRestartsIt() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 2)
        player.send(.ready(duration: nil))
        player.send(.time(1))

        useCase.previous()

        #expect(state.currentTrack?.id == "t2")
        #expect(player.calls.last == .seek(0))
        #expect(player.loads == ["t2"])
    }

    @Test func aFailedStreamStopsAndSaysSoWithoutSkipping() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)

        player.send(.failed)

        #expect(state.status == .failed)
        #expect(state.currentTrack?.id == "t0")
        #expect(player.calls.last == .stop)
        #expect(player.loads == ["t0"])
    }

    @Test func playPauseToggles() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))

        useCase.togglePlayPause()
        #expect(state.status == .paused && player.calls.last == .pause)
        useCase.togglePlayPause()
        #expect(state.status == .playing && player.calls.last == .play)
    }

    @Test func playPauseAfterAFailureTriesTheTrackAgain() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.failed)

        useCase.togglePlayPause()

        #expect(state.status == .loading)
        #expect(player.loads == ["t0", "t0"])
    }

    @Test func timeOnlyCountsWhilePlaying() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        player.send(.time(12))
        useCase.togglePlayPause()
        player.send(.time(13))

        #expect(state.elapsed == 12)
    }

    @Test func nothingPlaysSignedOut() {
        useCase(signedIn: false).play(tracks, startingAt: 0)
        #expect(player.loads.isEmpty)
        #expect(state.queue.isEmpty && state.currentTrack == nil)
    }

    @Test func aSecondPreviousRightAfterARestartGoesBack() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        useCase.next()
        player.send(.ready(duration: nil))
        player.send(.time(40))
        player.currentTime = 40

        useCase.previous()
        useCase.previous()

        #expect(state.currentTrack?.id == "t0")
    }

    @Test func aFailedLastTrackStaysFailed() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 3)
        player.send(.failed)

        useCase.next()
        useCase.seek(to: 30)

        #expect(state.status == .failed)
        #expect(!player.calls.contains(.play) && !player.calls.contains(.seek(30)))
    }

    @Test func previousFromAFailedTrackGoesBackOrRetries() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        useCase.next()
        player.send(.failed)
        useCase.previous()
        #expect(state.currentTrack?.id == "t0" && state.status == .loading)

        player.send(.failed)
        useCase.previous()
        #expect(state.currentTrack?.id == "t0" && state.status == .loading)
        #expect(player.loads == ["t0", "t1", "t0", "t0"])
    }

    @Test func pausingWhileLoadingHoldsWhenTheTrackIsReady() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        useCase.togglePlayPause()

        player.send(.ready(duration: 120))

        #expect(state.status == .paused && state.duration == 120)
    }

    @Test func seekingMovesTheElapsedTime() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))

        useCase.seek(to: 42)

        #expect(state.elapsed == 42 && player.calls.last == .seek(42))
    }

    // PLAY-6

    @Test func theLockScreenShowsTheTrackAndWhetherItPlays() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 1)
        #expect(lockScreen.last == NowPlayingInfo(title: "Song 1", artist: "Artist", album: "Album", duration: 200, elapsed: 0, isPlaying: false))

        player.send(.ready(duration: 210))
        #expect(lockScreen.last?.isPlaying == true && lockScreen.last?.duration == 210)

        player.send(.time(30))
        let published = lockScreen.updates.count
        player.send(.time(31))
        #expect(lockScreen.updates.count == published)

        useCase.togglePlayPause()
        #expect(lockScreen.last?.isPlaying == false && lockScreen.last?.elapsed == 31)
        useCase.seek(to: 90)
        #expect(lockScreen.last?.elapsed == 90)
    }

    @Test func lockScreenCommandsDriveThePlayer() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))

        lockScreen.send(.pause)
        #expect(state.status == .paused)
        lockScreen.send(.pause)
        #expect(state.status == .paused)
        lockScreen.send(.play)
        #expect(state.status == .playing)
        lockScreen.send(.togglePlayPause)
        #expect(state.status == .paused)
        lockScreen.send(.next)
        #expect(state.currentTrack?.id == "t1")
        lockScreen.send(.previous)
        #expect(state.currentTrack?.id == "t0")
        player.send(.ready(duration: nil))
        lockScreen.send(.seek(77))
        #expect(player.calls.last == .seek(77) && state.elapsed == 77)
        _ = useCase
    }

    // PLAY-7

    @Test func anInterruptionPausesAndResumesWhenTheSystemSaysSo() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))

        player.send(.interrupted)
        #expect(state.status == .paused)
        player.send(.interruptionEnded(shouldResume: true))
        #expect(state.status == .playing && player.calls.last == .play)
        _ = useCase
    }

    @Test func anInterruptionStaysPausedWhenTheSystemDoesntSaySo() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))

        player.send(.interrupted)
        player.send(.interruptionEnded(shouldResume: false))

        #expect(state.status == .paused)
        _ = useCase
    }

    @Test func anInterruptionWhilePausedDoesntStartPlayback() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        useCase.togglePlayPause()

        player.send(.interrupted)
        player.send(.interruptionEnded(shouldResume: true))

        #expect(state.status == .paused)
    }

    @Test func pausingDuringAnInterruptionCancelsTheResume() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        player.send(.interrupted)

        lockScreen.send(.pause)
        useCase.next()
        player.send(.ready(duration: nil))
        useCase.togglePlayPause()
        player.send(.interruptionEnded(shouldResume: true))

        #expect(state.status == .paused)
    }

    @Test func losingTheHeadphonesPauses() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))

        player.send(.outputLost)

        #expect(state.status == .paused && player.calls.last == .pause)
        _ = useCase
    }

    @Test func aTrackThatFailsDuringAnInterruptionDoesntComeBack() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        player.send(.interrupted)
        player.send(.failed)

        player.send(.interruptionEnded(shouldResume: true))

        #expect(state.status == .failed)
        #expect(!player.calls.contains(.play))
        _ = useCase
    }

    @Test func losingTheHeadphonesDuringAnInterruptionCancelsTheResume() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        player.send(.interrupted)
        player.send(.outputLost)

        player.send(.interruptionEnded(shouldResume: true))

        #expect(state.status == .paused)
        _ = useCase
    }

    @Test func endingTheQueueDuringAnInterruptionCancelsTheResume() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 3)
        player.send(.ready(duration: nil))
        player.send(.interrupted)
        useCase.next()

        player.send(.interruptionEnded(shouldResume: true))

        #expect(state.status == .paused)
    }

    @Test func theLockScreenClockStandsStillWhileBuffering() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        player.currentTime = 64

        player.send(.buffering(true))
        #expect(lockScreen.last?.isPlaying == false && lockScreen.last?.elapsed == 64)
        #expect(state.status == .playing)

        player.send(.buffering(false))
        #expect(lockScreen.last?.isPlaying == true)
        _ = useCase
    }

    // TRANS-3, TRANS-5

    @Test func eachTrackGetsTheQualityForTheNetworkItStartsOn() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        transcoding.network = .cellular
        useCase.next()

        #expect(player.qualities == [TranscodingSettings.defaults.wifi, TranscodingSettings.defaults.cellular])
        #expect(state.quality == TranscodingSettings.defaults.cellular)
    }

    @Test func aSettingsChangeAppliesFromTheNextTrack() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 0)
        player.send(.ready(duration: nil))
        let aac = StreamQuality(format: .aac, maxBitRate: 128)

        transcoding.update(TranscodingSettings(wifi: aac, cellular: aac))
        #expect(player.loads == ["t0"])
        #expect(state.quality == TranscodingSettings.defaults.wifi)
        useCase.next()

        #expect(player.qualities.last == aac)
    }

    @Test func stoppingUnloadsEverything() {
        let useCase = useCase()
        useCase.play(tracks, startingAt: 1)
        player.send(.ready(duration: 200))

        useCase.stop()

        #expect(state.queue.isEmpty && state.currentTrack == nil && state.status == .stopped)
        #expect(state.quality == nil && state.duration == nil && state.elapsed == 0)
        #expect(player.calls.last == .stop)
        #expect(lockScreen.updates.last == .some(nil))
    }

    // PLAY-9

    @Test func aShuffledListQueuesEveryTrackOnceInTheShufflesOrderAndStartsWithTheFirst() {
        let useCase = useCase(shuffle: { Array($0.reversed()) })

        useCase.playShuffled(tracks)

        #expect(state.queue.map(\.id) == ["t3", "t2", "t1", "t0"])
        #expect(state.currentTrack?.id == "t3" && state.status == .loading)
        #expect(player.loads == ["t3"])
    }

    @Test func nextAndPreviousFollowTheShuffledOrder() {
        let useCase = useCase(shuffle: { [$0[2], $0[0], $0[3], $0[1]] })
        useCase.playShuffled(tracks)
        player.send(.ready(duration: nil))

        useCase.next()
        #expect(state.currentTrack?.id == "t0")
        useCase.next()
        #expect(state.currentTrack?.id == "t3")
        player.send(.ready(duration: nil))
        player.send(.time(1))
        useCase.previous()
        #expect(state.currentTrack?.id == "t0")
        #expect(player.loads == ["t2", "t0", "t3", "t0"])
    }

    @Test func aShuffledQueueEndsLikeAnyOther() {
        let useCase = useCase(shuffle: { Array($0.reversed()) })
        useCase.playShuffled(Array(tracks.prefix(2)))
        player.send(.ready(duration: nil))

        player.send(.ended)
        player.send(.ready(duration: nil))
        player.send(.ended)

        #expect(state.currentTrack?.id == "t0" && state.status == .paused && state.elapsed == 0)
    }

    @Test func thereIsNoShuffleModeAfterwards() {
        let useCase = useCase(shuffle: { Array($0.reversed()) })
        useCase.playShuffled(tracks)

        useCase.play(tracks, startingAt: 0)

        #expect(state.queue.map(\.id) == ["t0", "t1", "t2", "t3"] && state.currentTrack?.id == "t0")
    }

    @Test func shufflingAgainShufflesAgain() {
        var calls = 0
        let useCase = useCase(shuffle: { list in
            calls += 1
            return calls == 1 ? list : Array(list.reversed())
        })

        useCase.playShuffled(tracks)
        let first = state.queue.map(\.id)
        useCase.playShuffled(tracks)

        #expect(first == ["t0", "t1", "t2", "t3"] && state.queue.map(\.id) == ["t3", "t2", "t1", "t0"])
    }

    @Test func theRealShuffleKeepsEveryTrackExactlyOnce() {
        let many = Track.numbered(200)
        let useCase = useCase()

        useCase.playShuffled(many)

        #expect(state.queue.count == 200 && Set(state.queue.map(\.id)) == Set(many.map(\.id)))
        #expect(state.queue.map(\.id) != many.map(\.id))
        #expect(state.currentTrack?.id == state.queue.first?.id)
    }

    @Test func nothingIsShuffledWithoutTracksOrSignedOut() {
        useCase().playShuffled([])
        useCase(signedIn: false).playShuffled(tracks)
        #expect(state.queue.isEmpty && player.loads.isEmpty)
    }
}
