import Testing
@testable import Scratch

@Suite(.timeLimit(.minutes(1)))
struct AlbumUseCaseTests {
    private let gateway = AlbumGatewayMock()
    private let albumsState = AlbumsState()
    private func useCase(signedIn: Bool = true) -> DefaultAlbumUseCase {
        DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: signedIn ? .sample : nil), albumsState: albumsState)
    }

    @Test func loadsInPagesOfAHundredUntilAShortPage() async throws {
        gateway.all = Album.numbered(250)
        let useCase = useCase()

        try await useCase.loadFirstPage()
        #expect(useCase.albums.count == 100 && useCase.hasMoreAlbums)
        try await useCase.loadNextPage()
        #expect(useCase.albums.count == 200 && useCase.hasMoreAlbums)
        try await useCase.loadNextPage()
        #expect(useCase.albums.count == 250 && !useCase.hasMoreAlbums)
        try await useCase.loadNextPage()

        #expect(gateway.requests.map(\.offset) == [0, 100, 200])
        #expect(gateway.requests.allSatisfy { $0.count == 100 })
        #expect(useCase.albums.map(\.id) == Album.numbered(250).map(\.id))
    }

    @Test func anExactMultipleEndsWithAnEmptyPage() async throws {
        gateway.all = Album.numbered(100)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        #expect(useCase.hasMoreAlbums)
        try await useCase.loadNextPage()
        #expect(!useCase.hasMoreAlbums && useCase.albums.count == 100)
    }

    @Test func theFirstPageReplacesWhatWasLoaded() async throws {
        gateway.all = Album.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        try await useCase.loadNextPage()

        gateway.all = Album.numbered(3)
        try await useCase.loadFirstPage()

        #expect(useCase.albums.count == 3 && !useCase.hasMoreAlbums)
    }

    @Test func aPageThatArrivesAfterAReloadIsDropped() async throws {
        gateway.all = Album.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()

        let hold = gateway.holdNextRequest()
        let next = Task { try await useCase.loadNextPage() }
        for await _ in hold.entered { break }
        gateway.all = Album.numbered(5)
        try await useCase.loadFirstPage()
        hold.release()
        try await next.value

        #expect(useCase.albums.map(\.id) == Album.numbered(5).map(\.id))
    }

    @Test func noNextPageStartsWhileAReloadRuns() async throws {
        gateway.all = Album.numbered(150)
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
        #expect(useCase.albums.map(\.id) == Album.numbered(150).map(\.id))
    }

    @Test func anAlbumThatComesRoundAgainIsNotRepeated() async throws {
        gateway.all = Album.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        // The server's order shifted by one: the next page starts with an album already shown.
        gateway.all.insert(Album.numbered(1)[0], at: 0)
        try await useCase.loadNextPage()

        #expect(useCase.albums.count == 150)
        #expect(Set(useCase.albums.map(\.id)).count == useCase.albums.count)
    }

    @Test func errorsLeaveTheListAsItWas() async throws {
        gateway.all = Album.numbered(150)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        gateway.error = .unreachable

        await #expect(throws: ServerError.unreachable) { try await useCase.loadNextPage() }
        #expect(useCase.albums.count == 100 && useCase.hasMoreAlbums)
    }

    @Test func aPageForAServerSignedOutOfIsDropped() async throws {
        gateway.all = Album.numbered(150)
        let session = SessionState(server: .sample)
        let useCase = DefaultAlbumUseCase(albumGateway: gateway, sessionState: session, albumsState: albumsState)
        try await useCase.loadFirstPage()

        let hold = gateway.holdNextRequest()
        let next = Task { try await useCase.loadNextPage() }
        for await _ in hold.entered { break }
        session.server = nil
        albumsState.albums = []
        gateway.error = .wrongCredentials
        hold.release()

        try await next.value
        #expect(albumsState.albums.isEmpty)
    }

    @Test func signedOutLoadsNothing() async throws {
        try await useCase(signedIn: false).loadFirstPage()
        #expect(gateway.requests.isEmpty)
    }

    @Test func theNextPageStartsWhereTheServerStoppedWhateverWasShown() async throws {
        gateway.all = Album.numbered(250)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        // An album the server returned is taken out of the grid, as the favourites will be.
        albumsState.albums.remove(at: 0)

        try await useCase.loadNextPage()

        #expect(gateway.requests.map(\.offset) == [0, 100])
    }
}
