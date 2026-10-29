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

    // ALB-3

    @Test func favouritesComeFirstByNameAndAreNotRepeated() async throws {
        gateway.all = Album.numbered(30)
        // The server lists them by when they were starred; the use case orders them by name, numbers as numbers.
        gateway.starred = [gateway.all[12], gateway.all[3], gateway.all[7]]
        let useCase = useCase()

        try await useCase.loadFirstPage()

        #expect(useCase.favourites.map(\.name) == ["Album 3", "Album 7", "Album 12"])
        #expect(useCase.albums.count == 27)
        #expect(!useCase.albums.contains { ["a3", "a7", "a12"].contains($0.id) })
        #expect(gateway.starredRequests == 1)
    }

    @Test func namesAreOrderedTheWayPeopleReadThem() async throws {
        gateway.starred = ["b", "A", "a10", "a9", "C"].map { Album(id: $0, name: $0, artist: "", coverArtID: nil, songCount: nil, duration: nil, year: nil, genre: nil, isStarred: true) }
        let useCase = useCase()

        try await useCase.loadFirstPage()

        #expect(useCase.favourites.map(\.name) == ["A", "a9", "a10", "b", "C"])
    }

    @Test func noFavouritesMeansNone() async throws {
        gateway.all = Album.numbered(5)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        #expect(useCase.favourites.isEmpty && useCase.albums.count == 5)
    }

    @Test func favouritesAreLeftOutOfLaterPagesToo() async throws {
        gateway.all = Album.numbered(250)
        gateway.starred = [gateway.all[150], gateway.all[199]]
        let useCase = useCase()

        try await useCase.loadFirstPage()
        try await useCase.loadNextPage()
        try await useCase.loadNextPage()

        #expect(useCase.albums.count == 248)
        #expect(!useCase.albums.contains { $0.id == "a150" || $0.id == "a199" })
        #expect(gateway.requests.map(\.offset) == [0, 100, 200])
    }

    @Test func aFavouritesRequestThatFailsFailsTheLoadAndKeepsWhatWasShown() async throws {
        gateway.all = Album.numbered(5)
        gateway.starred = [gateway.all[0]]
        let useCase = useCase()
        try await useCase.loadFirstPage()
        gateway.starredError = .unreachable

        await #expect(throws: ServerError.unreachable) { try await useCase.loadFirstPage() }

        #expect(useCase.favourites.count == 1 && useCase.albums.count == 4)
    }

    @Test func aFirstPageThatFailsFailsTheLoadToo() async throws {
        gateway.all = Album.numbered(5)
        gateway.error = .unreachable
        await #expect(throws: ServerError.unreachable) { try await useCase().loadFirstPage() }
    }

    @Test func aPageOfNothingButFavouritesLoadsTheNextOne() async throws {
        gateway.all = Album.numbered(250)
        gateway.starred = Array(gateway.all.prefix(150))
        let useCase = useCase()

        try await useCase.loadFirstPage()

        #expect(useCase.favourites.count == 150)
        #expect(useCase.albums.map(\.id) == (150..<200).map { "a\($0)" })
        #expect(gateway.requests.map(\.offset) == [0, 100])
        #expect(useCase.hasMoreAlbums)
    }

    @Test func aLaterPageOfNothingButFavouritesLoadsTheNextOne() async throws {
        gateway.all = Album.numbered(350)
        gateway.starred = Array(gateway.all[100..<200])
        let useCase = useCase()
        try await useCase.loadFirstPage()

        try await useCase.loadNextPage()

        #expect(gateway.requests.map(\.offset) == [0, 100, 200])
        #expect(useCase.albums.count == 200)
    }

    @Test func aReloadReplacesTheFavouritesToo() async throws {
        gateway.all = Album.numbered(5)
        gateway.starred = [gateway.all[0], gateway.all[1]]
        let useCase = useCase()
        try await useCase.loadFirstPage()

        gateway.starred = [gateway.all[4]]
        try await useCase.loadFirstPage()

        #expect(useCase.favourites.map(\.id) == ["a4"] && useCase.albums.count == 4)
    }

    @Test func favouritesFromBeforeAReloadAreDropped() async throws {
        gateway.all = Album.numbered(5)
        gateway.starred = [gateway.all[0]]
        let useCase = useCase()
        let hold = gateway.holdNextStarredRequest()

        let first = Task { try await useCase.loadFirstPage() }
        for await _ in hold.entered { break }
        gateway.starred = [gateway.all[4]]
        try await useCase.loadFirstPage()
        hold.release()
        try await first.value

        #expect(useCase.favourites.map(\.id) == ["a4"] && useCase.albums.count == 4)
    }

    @Test func favouritesForAServerSignedOutOfAreDropped() async throws {
        gateway.all = Album.numbered(5)
        gateway.starred = [gateway.all[0]]
        let session = SessionState(server: .sample)
        let useCase = DefaultAlbumUseCase(albumGateway: gateway, sessionState: session, albumsState: albumsState)
        let hold = gateway.holdNextStarredRequest()

        let load = Task { try await useCase.loadFirstPage() }
        for await _ in hold.entered { break }
        session.server = nil
        hold.release()
        try await load.value

        #expect(albumsState.favourites.isEmpty && albumsState.albums.isEmpty)
    }

    @Test func aRepeatedFavouriteIsShownOnce() async throws {
        gateway.all = Album.numbered(3)
        gateway.starred = [gateway.all[1], gateway.all[1]]
        let useCase = useCase()
        try await useCase.loadFirstPage()
        #expect(useCase.favourites.map(\.id) == ["a1"])
    }

    @Test func aServerThatIgnoresTheOffsetCantKeepALoadRunning() async throws {
        gateway.all = Album.numbered(150)
        gateway.starred = Array(gateway.all.prefix(100))
        gateway.ignoresOffset = true
        let useCase = useCase()

        try await useCase.loadFirstPage()
        #expect(gateway.requests.count == 1 + DefaultAlbumUseCase.maxGapPages)

        try await useCase.loadNextPage()
        #expect(gateway.requests.count == 1 + 2 * DefaultAlbumUseCase.maxGapPages)
    }

    @Test func aPageThatFailsWhileFillingTheGapFailsTheLoadAndARetryRecovers() async throws {
        gateway.all = Album.numbered(250)
        gateway.starred = Array(gateway.all.prefix(150))
        gateway.failAfterRequests = 1
        let useCase = useCase()

        await #expect(throws: ServerError.unreachable) { try await useCase.loadFirstPage() }

        gateway.failAfterRequests = nil
        try await useCase.loadFirstPage()
        #expect(useCase.favourites.count == 150 && useCase.albums.count == 50)
    }

    @Test func aNextPageCanStartWhileAStaleOneIsStillOut() async throws {
        gateway.all = Album.numbered(250)
        let useCase = useCase()
        try await useCase.loadFirstPage()
        let hold = gateway.holdNextRequest()
        let stale = Task { try await useCase.loadNextPage() }
        for await _ in hold.entered { break }

        try await useCase.loadFirstPage()
        try await useCase.loadNextPage()
        #expect(useCase.albums.count == 200)

        hold.release()
        try await stale.value
        #expect(useCase.albums.count == 200)
    }
}
