import Foundation
import Testing
@testable import Scratch

struct PlaybackUseCaseTests {
    private let player = AudioPlayerGatewayMock()
    private let state = PlaybackState()
    private let tracks = Track.numbered(4)
    private func useCase(signedIn: Bool = true) -> DefaultPlaybackUseCase {
        DefaultPlaybackUseCase(audioPlayer: player, sessionState: SessionState(server: signedIn ? .sample : nil), playbackState: state)
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
}
