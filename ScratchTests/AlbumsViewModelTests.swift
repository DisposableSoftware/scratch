import Foundation
import Testing
import UIKit
@testable import Scratch

private struct AlbumsUseCases: HasAlbumUseCase, HasCoverArtUseCase, HasTranscodingUseCase, HasSessionUseCase,
    HasAppRoutingUseCase, HasCoordinator {
    let albumUseCase: AlbumUseCase
    let coverArtUseCase: CoverArtUseCase
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
    private var viewModel: AlbumsViewModel {
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: .sample), albumsState: AlbumsState())
        return AlbumsViewModel(useCases: AlbumsUseCases(albumUseCase: albums, coverArtUseCase: art, coordinator: coordinator))
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
