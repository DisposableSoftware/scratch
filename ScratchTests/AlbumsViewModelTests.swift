import Foundation
import Testing
import UIKit
@testable import Scratch

private struct AlbumsUseCases: HasAlbumUseCase, HasCoverArtUseCase, HasPlaybackUseCase, HasTranscodingUseCase,
    HasDisplayUseCase, HasSessionUseCase, HasAppRoutingUseCase, HasCoordinator {
    let albumUseCase: AlbumUseCase
    let coverArtUseCase: CoverArtUseCase
    var playbackUseCase: PlaybackUseCase = PlaybackUseCaseMock()
    var displayUseCase: DisplayUseCase = DisplayUseCaseMock()
    var transcodingUseCase: TranscodingUseCase = TranscodingUseCaseMock()
    var sessionUseCase: SessionUseCase = SessionUseCaseMock()
    var appRouting: AppRoutingUseCase = AppRoutingUseCaseSpy()
    var coordinator: Coordinator = CoordinatorSpy()
}

@Suite(.timeLimit(.minutes(1)))

struct AlbumsViewModelTests {
    private let gateway = AlbumGatewayMock()
    private let art = CoverArtUseCaseMock()
    private let coordinator = CoordinatorSpy()
    private let session = SessionUseCaseMock()
    private let routing = AppRoutingUseCaseSpy()

    private var viewModel: AlbumsViewModel {
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        return AlbumsViewModel(useCases: AlbumsUseCases(
            albumUseCase: albums, coverArtUseCase: art, sessionUseCase: session, appRouting: routing, coordinator: coordinator
        ))
    }

    private func png() -> Data? { UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData() }

    @Test func showsTheFirstPage() async {
        gateway.all = Album.numbered(3)
        let viewModel = viewModel

        #expect(viewModel.phase == .loading)

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.albums == Album.numbered(3))
        #expect(viewModel.columns == 2)
    }

    @Test func favouritesAreShownAboveTheOthers() async {
        gateway.all = Album.numbered(10)
        gateway.starred = [gateway.all[2]]
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.favourites.map(\.id) == ["a2"])
        #expect(viewModel.albums.count == 9 && !viewModel.albums.contains { $0.id == "a2" })
    }

    @Test func aServerWithOnlyFavouritesIsNotEmpty() async {
        gateway.all = Album.numbered(2)
        gateway.starred = gateway.all
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded && viewModel.favourites.count == 2 && viewModel.albums.isEmpty)
    }

    @Test func aFailedFavouritesRequestShowsTheError() async {
        gateway.all = Album.numbered(3)
        gateway.starredError = .unreachable
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }

        #expect(message.contains("Couldn't reach the server"))
        gateway.starredError = nil
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded)
    }

    // ALB-5

    @Test func pullToRefreshReloadsTheFavouritesAndTheFirstPageWithTheGridStillShown() async {
        gateway.all = Album.numbered(150)
        gateway.starred = [gateway.all[1]]
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.albumAppeared("a99"))

        #expect(viewModel.albums.count == 149 && viewModel.favourites.count == 1)

        gateway.all = Album.numbered(6)
        gateway.starred = [gateway.all[5], gateway.all[4]]
        let hold = gateway.holdNextRequest()
        let refresh = Task { await viewModel.handleAction(.refresh) }
        for await _ in hold.entered { break }

        #expect(viewModel.phase == .loaded && viewModel.albums.count == 149)
        hold.release()
        _ = await refresh.value

        #expect(viewModel.favourites.map(\.id) == ["a4", "a5"])
        #expect(viewModel.albums.map(\.id) == ["a0", "a1", "a2", "a3"])
        #expect(gateway.requests.last?.offset == 0 && gateway.starredRequests == 2)
    }

    @Test func pagingStartsOverAfterARefresh() async {
        gateway.all = Album.numbered(250)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.albumAppeared("a99"))
        _ = await viewModel.handleAction(.albumAppeared("a199"))

        #expect(viewModel.albums.count == 250)

        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.albums.count == 100)
        _ = await viewModel.handleAction(.albumAppeared("a99"))

        #expect(viewModel.albums.count == 200)
    }

    @Test func aRefreshWhileANextPageIsInFlightEndsCleanAndPagingWorks() async {
        gateway.all = Album.numbered(250)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        let hold = gateway.holdNextRequest()
        let next = Task { await viewModel.handleAction(.albumAppeared("a99")) }
        for await _ in hold.entered { break }

        #expect(viewModel.isLoadingMore)

        _ = await viewModel.handleAction(.refresh)

        #expect(!viewModel.isLoadingMore && viewModel.loadMoreError == nil && viewModel.albums.count == 100)
        _ = await viewModel.handleAction(.albumAppeared("a99"))

        #expect(viewModel.albums.count == 200)

        hold.release()
        _ = await next.value

        #expect(viewModel.albums.count == 200 && viewModel.loadMoreError == nil && !viewModel.isLoadingMore)
    }

    @Test func anEmptyServerCanBeRefreshed() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty)

        gateway.all = Album.numbered(2)
        _ = await viewModel.handleAction(.refresh)

        #expect(viewModel.phase == .loaded && viewModel.albums.count == 2)
    }

    @Test func aFailedRefreshSaysWhyWithRetry() async {
        gateway.all = Album.numbered(3)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .unreachable

        _ = await viewModel.handleAction(.refresh)

        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }

        #expect(message.contains("Couldn't reach the server"))
        gateway.error = nil
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded && viewModel.albums.count == 3)
    }

    @Test func aRefreshWhileTheFirstLoadRunsDoesNothingMore() async {
        gateway.all = Album.numbered(3)
        let hold = gateway.holdNextRequest()
        let viewModel = viewModel
        let first = Task { await viewModel.handleAction(.lifecycle(.viewDidAppear)) }
        for await _ in hold.entered { break }

        _ = await viewModel.handleAction(.refresh)
        hold.release()
        _ = await first.value

        #expect(gateway.requests.count == 1 && viewModel.phase == .loaded)
    }

    // ALB-17, ALB-18

    @Test func theGridHasAsManyColumnsAsTheSettingSays() async {
        let display = DisplayUseCaseMock()
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        let viewModel = AlbumsViewModel(useCases: AlbumsUseCases(albumUseCase: albums, coverArtUseCase: art, displayUseCase: display, coordinator: coordinator))

        #expect(viewModel.columns == 2)

        display.setAlbumsPerRow(5)

        #expect(viewModel.columns == 5)
        display.setAlbumsPerRow(1)

        #expect(viewModel.columns == 1)
    }

    @Test func aChangeReLaysTheGridWithoutReloadingIt() async {
        gateway.all = Album.numbered(150)
        gateway.starred = [gateway.all[0]]
        let display = DisplayUseCaseMock()
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        let viewModel = AlbumsViewModel(useCases: AlbumsUseCases(albumUseCase: albums, coverArtUseCase: art, displayUseCase: display, coordinator: coordinator))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.albumAppeared("a99"))
        let requests = gateway.requests.count

        display.setAlbumsPerRow(4)

        #expect(viewModel.columns == 4 && viewModel.phase == .loaded)
        #expect(viewModel.albums.count == 149 && viewModel.favourites.count == 1)
        #expect(gateway.requests.count == requests && gateway.starredRequests == 1)
    }

    @Test func theSettingsSheetAndTheGridShareTheSettingAndItIsSaved() async {
        let settings = SettingsGatewayMock()
        let display = DefaultDisplayUseCase(settingsGateway: settings, displayState: DisplayState())
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        let useCases = AlbumsUseCases(albumUseCase: albums, coverArtUseCase: art, displayUseCase: display, coordinator: coordinator)
        let grid = AlbumsViewModel(useCases: useCases)
        let sheet = SettingsViewModel(useCases: useCases)

        #expect(grid.columns == 2 && sheet.albumsPerRow == 2)

        _ = await sheet.handleAction(.albumsPerRowChanged(5))

        #expect(grid.columns == 5 && sheet.albumsPerRow == 5 && settings.savedAlbumsPerRow == 5)

        // A restart: a new state and use case over the same saved settings.
        let restarted = DefaultDisplayUseCase(settingsGateway: settings, displayState: DisplayState())

        #expect(restarted.state.albumsPerRow == 5)
    }

    // ALB-8

    @Test func tappingAnAlbumPushesItsScreenThroughTheCoordinator() async {
        gateway.all = Album.numbered(3)
        gateway.starred = [gateway.all[2]]
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.albumTapped("a1"))
        _ = await viewModel.handleAction(.albumTapped("a2"))

        #expect(coordinator.destinations.count == 2)
        var keys: [String] = []

        for destination in coordinator.destinations {
            guard case .push(let key, _) = destination else {
                Issue.record("expected a push, got \(destination)")
                return
            }

            keys.append(key)
        }

        #expect(keys == ["album:a1", "album:a2"])
    }

    @Test func tappingAnAlbumThatIsntThereDoesNothing() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.albumTapped("nope"))

        #expect(coordinator.destinations.isEmpty)
    }

    // ALB-16

    @Test(arguments: [ServerError.wrongCredentials, .failed(code: 41, message: "Token authentication not supported")])

    func aRejectedFirstLoadGoesBackToSetup(error: ServerError) async {
        gateway.error = error
        let viewModel = viewModel

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1 && routing.steps == [.library])
        #expect(viewModel.phase == .loading)
    }

    @Test func aRejectedFavouritesRequestGoesBackToSetup() async {
        gateway.all = Album.numbered(3)
        gateway.starredError = .wrongCredentials
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1 && routing.steps == [.library])
    }

    @Test func aRejectedNextPageGoesBackToSetupWithoutAnErrorUnderTheGrid() async {
        gateway.all = Album.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .wrongCredentials

        _ = await viewModel.handleAction(.albumAppeared("a99"))

        #expect(session.rejections == 1 && routing.steps == [.library] && viewModel.loadMoreError == nil)
    }

    @Test func aRejectionWhileFillingTheGapGoesBackToSetup() async {
        // Every album of the first page is a favourite, so the next page is taken at once, and
        // that one is turned away.
        gateway.all = Album.numbered(250)
        gateway.starred = Array(gateway.all.prefix(100))
        gateway.failAfterRequests = 1
        gateway.failAfterError = .wrongCredentials

        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 1 && routing.steps == [.library])
    }

    @Test func aRejectedRefreshGoesBackToSetup() async {
        gateway.all = Album.numbered(3)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .wrongCredentials

        _ = await viewModel.handleAction(.refresh)

        #expect(session.rejections == 1 && routing.steps == [.library])
    }

    @Test func otherErrorsDontSignOut() async {
        gateway.error = .failed(code: 70, message: "Not found")
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(session.rejections == 0 && routing.steps.isEmpty)
    }

    @Test func anEmptyServerSaysSo() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .empty)
    }

    @Test func aFailedLoadShowsWhyAndRetries() async {
        gateway.error = .unreachable
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }

        #expect(message.contains("Couldn't reach the server"))

        gateway.error = nil
        gateway.all = Album.numbered(2)
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.phase == .loaded && viewModel.albums.count == 2)
    }

    @Test func albumsNearTheEndLoadTheNextPage() async {
        gateway.all = Album.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.albumAppeared("a10"))

        #expect(viewModel.albums.count == 100)
        _ = await viewModel.handleAction(.albumAppeared("a85"))

        #expect(viewModel.albums.count == 150)
        #expect(gateway.requests.map(\.offset) == [0, 100])
    }

    @Test func aFailedNextPageKeepsTheGridAndOffersRetry() async {
        gateway.all = Album.numbered(150)
        let viewModel = viewModel
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        gateway.error = .unreachable

        _ = await viewModel.handleAction(.albumAppeared("a99"))

        #expect(viewModel.phase == .loaded && viewModel.albums.count == 100)
        #expect(viewModel.loadMoreError != nil)

        gateway.error = nil
        _ = await viewModel.handleAction(.retry)

        #expect(viewModel.albums.count == 150 && viewModel.loadMoreError == nil)
    }

    @Test func overlappingFirstLoadsDontFlashEmpty() async {
        gateway.all = Album.numbered(3)
        let hold = gateway.holdNextRequest()
        let viewModel = viewModel

        let first = Task { await viewModel.handleAction(.lifecycle(.viewDidAppear)) }
        for await _ in hold.entered { break }
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loading)
        hold.release()
        _ = await first.value

        #expect(viewModel.phase == .loaded && viewModel.albums.count == 3)
        #expect(gateway.requests.count == 1)
    }

    // ALB-7

    @Test func coversAreFetchedOncePerAlbumAtTheCellsSize() async {
        art.data = png()
        let viewModel = viewModel

        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))

        #expect(art.requests.count == 1 && art.requests.first?.pixelSize == 360)
        #expect(viewModel.artwork["c1"] != nil)
    }

    @Test func aLargerSizeFetchesTheCoverAgainAndASmallerOneDoesnt() async {
        art.data = png()
        let viewModel = viewModel
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 180))

        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 144))

        #expect(art.requests.map(\.pixelSize) == [180, 360])
        #expect(viewModel.artwork["c1"] != nil)
    }

    @Test func aPixelOfDifferenceBetweenCellsFetchesNothingMore() async {
        art.data = png()
        let viewModel = viewModel
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 359))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c2", pixelSize: 360))

        #expect(art.requests.count == 2)
        #expect(viewModel.artwork["c1"] != nil && viewModel.artwork["c2"] != nil)
    }

    @Test func aSizeAskedForWhileAFetchRunsIsFetchedAfterIt() async {
        art.data = png()
        let hold = art.holdNextRequest()
        let viewModel = viewModel

        let first = Task { await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 180)) }
        for await _ in hold.entered { break }
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))
        hold.release()
        _ = await first.value

        #expect(art.requests.map(\.pixelSize) == [180, 360])
        #expect(viewModel.artwork["c1"] != nil)
    }

    @Test func twoAsksForTheSameCoverWhileItLoadsFetchItOnce() async {
        art.data = png()
        let hold = art.holdNextRequest()
        let viewModel = viewModel

        let first = Task { await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360)) }
        for await _ in hold.entered { break }
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))
        hold.release()
        _ = await first.value

        #expect(art.requests.count == 1)
    }

    @Test func aFailedCoverIsAskedForAgain() async {
        let viewModel = viewModel
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))

        #expect(viewModel.artwork["c1"] == nil)

        art.data = png()
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c1", pixelSize: 360))

        #expect(art.requests.count == 2 && viewModel.artwork["c1"] != nil)
    }

    @Test func keepsOnlyTheMostRecentCovers() async {
        art.data = png()
        let viewModel = viewModel

        for index in 0...AlbumsViewModel.artworkLimit {
            _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c\(index)", pixelSize: 360))
        }

        #expect(viewModel.artwork.count == AlbumsViewModel.artworkLimit && viewModel.artwork["c0"] == nil)
        _ = await viewModel.handleAction(.artworkNeeded(coverArtID: "c0", pixelSize: 360))

        #expect(viewModel.artwork["c0"] != nil)
        #expect(viewModel.artwork.count == AlbumsViewModel.artworkLimit)
    }

    @Test func theSettingsButtonOpensSettingsAsASheet() async {
        _ = await viewModel.handleAction(.settingsTapped)
        guard case .sheet = coordinator.destinations.last else {
            Issue.record("expected a sheet, got \(coordinator.destinations)")
            return
        }
    }
}
