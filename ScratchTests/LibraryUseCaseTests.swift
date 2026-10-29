import Testing
@testable import Scratch

@Suite(.timeLimit(.minutes(1)))

struct LibraryUseCaseTests {
    private let gateway = LibraryGatewayMock()
    private let library = LibraryState()

    private func useCase(signedIn: Bool = true) -> DefaultLibraryUseCase {
        DefaultLibraryUseCase(libraryGateway: gateway, sessionState: SessionState(server: signedIn ? .sample : nil), libraryState: library)
    }

    @Test func loadsInPagesOfAHundredUntilAShortPage() async throws {
        gateway.all = Track.numbered(250)
        let useCase = useCase()

        try await useCase.loadFirstPage()

        #expect(useCase.tracks.count == 100 && useCase.hasMoreTracks)
        try await useCase.loadNextPage()

        #expect(useCase.tracks.count == 200 && useCase.hasMoreTracks)
        try await useCase.loadNextPage()

        #expect(useCase.tracks.count == 250 && !useCase.hasMoreTracks)
        try await useCase.loadNextPage()

        #expect(gateway.requests.map(\.offset) == [0, 100, 200])
        #expect(gateway.requests.allSatisfy { $0.count == 100 })
        #expect(useCase.tracks.map(\.id) == Track.numbered(250).map(\.id))
    }

    @Test func anExactMultipleEndsWithAnEmptyPage() async throws {
        gateway.all = Track.numbered(100)
        let useCase = useCase()
        try await useCase.loadFirstPage()

        #expect(useCase.hasMoreTracks)
        try await useCase.loadNextPage()

        #expect(!useCase.hasMoreTracks && useCase.tracks.count == 100)
    }

    @Test func theFirstPageReplacesWhatWasLoaded() async throws {
        gateway.all = Track.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        try await useCase.loadNextPage()

        gateway.all = Track.numbered(3)
        try await useCase.loadFirstPage()

        #expect(useCase.tracks.count == 3 && !useCase.hasMoreTracks)
    }

    @Test func aPageThatArrivesAfterAReloadIsDropped() async throws {
        gateway.all = Track.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()

        // Hold the next-page request open while a reload happens.
        let hold = gateway.holdNextRequest()
        let next = Task { try await useCase.loadNextPage() }
        for await _ in hold.entered { break }
        gateway.all = Track.numbered(5)
        try await useCase.loadFirstPage()
        hold.release()
        try await next.value

        #expect(useCase.tracks.map(\.id) == Track.numbered(5).map(\.id))
    }

    @Test func aTrackThatComesRoundAgainIsNotRepeated() async throws {
        gateway.all = Track.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()

        // The server's order shifted by one: the next page starts with a track already shown.
        gateway.all.insert(Track.numbered(1)[0], at: 0)
        try await useCase.loadNextPage()

        #expect(useCase.tracks.count == 150)
        #expect(Set(useCase.tracks.map(\.id)).count == useCase.tracks.count)
    }

    @Test func errorsLeaveTheListAsItWas() async throws {
        gateway.all = Track.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        gateway.error = .unreachable

        await #expect(throws: ServerError.unreachable) { try await useCase.loadNextPage() }
        #expect(useCase.tracks.count == 100 && useCase.hasMoreTracks)
    }

    @Test func signedOutLoadsNothing() async throws {
        try await useCase(signedIn: false).loadFirstPage()

        #expect(gateway.requests.isEmpty)
    }

    @Test func noNextPageStartsWhileAReloadRuns() async throws {
        gateway.all = Track.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        try await useCase.loadNextPage()

        let hold = gateway.holdNextRequest()
        let reload = Task { try await useCase.loadFirstPage() }
        for await _ in hold.entered { break }
        try await useCase.loadNextPage()
        hold.release()
        try await reload.value

        #expect(gateway.requests.map(\.offset) == [0, 100, 0])
        try await useCase.loadNextPage()

        #expect(useCase.tracks.map(\.id) == Track.numbered(150).map(\.id))
    }

    @Test func aNextPageThatFailsAfterAReloadIsForgotten() async throws {
        gateway.all = Track.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()

        let hold = gateway.holdNextRequest()
        let next = Task { try await useCase.loadNextPage() }
        for await _ in hold.entered { break }
        try await useCase.loadFirstPage()
        gateway.error = .unreachable
        hold.release()

        try await next.value

        #expect(useCase.tracks.count == 100)
    }

    @Test func aPageForAServerSignedOutOfIsDropped() async throws {
        gateway.all = Track.numbered(150)
        let session = SessionState(server: .sample)
        let useCase = DefaultLibraryUseCase(libraryGateway: gateway, sessionState: session, libraryState: library)
        try await useCase.loadFirstPage()

        let hold = gateway.holdNextRequest()
        let next = Task { try await useCase.loadNextPage() }
        for await _ in hold.entered { break }
        session.server = nil
        library.tracks = []
        gateway.error = .wrongCredentials
        hold.release()

        try await next.value

        #expect(library.tracks.isEmpty)
    }
}
