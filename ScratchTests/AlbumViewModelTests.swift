import Foundation
import Testing
import UIKit
@testable import Scratch

private struct AlbumUseCases: HasAlbumUseCase, HasCoverArtUseCase, HasPlaybackUseCase {
    let albumUseCase: AlbumUseCase
    let coverArtUseCase: CoverArtUseCase
    let playbackUseCase: PlaybackUseCase
}

@Suite(.timeLimit(.minutes(1)))
struct AlbumViewModelTests {
    private let gateway = AlbumGatewayMock()
    private let art = CoverArtUseCaseMock()
    private let playback = PlaybackUseCaseMock()
    private func viewModel(_ detail: AlbumDetail? = nil, album: Album? = nil, signedIn: Bool = true) -> AlbumViewModel {
        if let detail { gateway.details[detail.album.id] = detail }
        let albums = DefaultAlbumUseCase(albumGateway: gateway, sessionState: SessionState(server: signedIn ? .sample : nil), albumsState: AlbumsState())
        let shown = album ?? detail?.album ?? Album.numbered(1)[0]
        return AlbumViewModel(album: shown, useCases: AlbumUseCases(albumUseCase: albums, coverArtUseCase: art, playbackUseCase: playback))
    }
    private func png() -> Data? { UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData() }

    // ALB-9

    @Test func theScreenStartsWithTheInfoTheGridHad() {
        let viewModel = viewModel(album: Album(id: "a", name: "Fire", artist: "Electric Six", coverArtID: "c", songCount: 12, duration: 2400, year: 2003, genre: "Rock", isStarred: false))
        #expect(viewModel.phase == .loading && viewModel.sections.isEmpty)
        #expect(viewModel.details == "2003 · Rock · 12 songs · 40 min")
        #expect(viewModel.album.name == "Fire")
    }

    @Test(arguments: [
        (Album(id: "a", name: "A", artist: "", coverArtID: nil, songCount: 1, duration: 59, year: nil, genre: nil, isStarred: false), "1 song · 1 min"),
        (Album(id: "a", name: "A", artist: "", coverArtID: nil, songCount: 67, duration: 7260, year: 2000, genre: "Game", isStarred: false), "2000 · Game · 67 songs · 2 hr 1 min"),
        (Album(id: "a", name: "A", artist: "", coverArtID: nil, songCount: nil, duration: nil, year: 1999, genre: "", isStarred: false), "1999"),
        (Album(id: "a", name: "A", artist: "", coverArtID: nil, songCount: nil, duration: 0, year: nil, genre: nil, isStarred: false), ""),
    ])
    func theInfoShowsOnlyWhatTheServerHas(album: Album, expected: String) {
        #expect(viewModel(album: album).details == expected)
    }

    @Test func theTrackCountFillsInWhenTheServerGaveNone() async {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: 3)
        detail.album.songCount = nil
        detail.album.duration = nil
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        #expect(viewModel.details == "2000 · Game · 3 songs")
    }

    // ALB-10, ALB-11

    @Test func aSingleDiscHasOneSectionAndNoHeader() async {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 3))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.sections.map(\.header) == [nil])
        #expect(viewModel.sections.first?.rows.map(\.title) == ["Track 1", "Track 2", "Track 3"])
    }

    @Test func severalDiscsGetAHeaderEachWithTheirTitleWhenTheyHaveOne() async {
        let viewModel = viewModel(.numbered(discs: 3, perDisc: 2, titles: [2: "Development"]))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        #expect(viewModel.sections.map(\.header) == ["Disc 1", "Disc 2 · Development", "Disc 3"])
        #expect(viewModel.sections.map { $0.rows.count } == [2, 2, 2])
    }

    @Test func aRowShowsItsNumberTitleAndDuration() async throws {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 2))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        let row = try #require(viewModel.sections.first?.rows.last)
        #expect(row == AlbumRow(id: "d1t2", number: "2", title: "Track 2", artist: nil, duration: "3:20"))
    }

    @Test func aRowShowsItsArtistOnlyWhenItDiffersFromTheAlbums() async throws {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: 3)
        detail.tracks[1].track.artist = "Guest"
        detail.tracks[2].track.artist = ""
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        let rows = try #require(viewModel.sections.first?.rows)

        #expect(rows.map(\.artist) == [nil, "Guest", nil])
    }

    @Test func aTrackWithNoNumberOrDurationShowsBlanks() async throws {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: 1)
        detail.tracks[0].number = nil
        detail.tracks[0].track.duration = nil
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        let row = try #require(viewModel.sections.first?.rows.first)
        #expect(row.number == "" && row.duration == nil)
    }

    // ALB-12, ALB-13

    @Test func tappingATrackPlaysItAndQueuesWhatFollowsAcrossDiscs() async throws {
        let detail = AlbumDetail.numbered(discs: 2, perDisc: 3)
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.trackTapped("d1t3"))

        let played = try #require(playback.played.first)
        #expect(played.tracks.map(\.id) == ["d1t1", "d1t2", "d1t3", "d2t1", "d2t2", "d2t3"])
        #expect(played.index == 2)
    }

    @Test func playStartsFromTheFirstTrack() async throws {
        let viewModel = viewModel(.numbered(discs: 2, perDisc: 2))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.playTapped)

        let played = try #require(playback.played.first)
        #expect(played.index == 0 && played.tracks.count == 4)
    }

    @Test func shuffleHandsEveryTrackOfTheAlbumToThePlayerInDiscOrder() async throws {
        let viewModel = viewModel(.numbered(discs: 2, perDisc: 3))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))

        _ = await viewModel.handleAction(.shuffleTapped)

        let shuffled = try #require(playback.shuffled.first)
        #expect(shuffled.map(\.id) == ["d1t1", "d1t2", "d1t3", "d2t1", "d2t2", "d2t3"])
        #expect(playback.played.isEmpty)
    }

    @Test func playAndShuffleBeforeTheTracksHaveLoadedPlayNothing() async {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 2))
        _ = await viewModel.handleAction(.shuffleTapped)
        _ = await viewModel.handleAction(.playTapped)
        #expect(playback.shuffled.isEmpty && playback.played.isEmpty)
    }

    @Test func tappingATrackThatIsntThereDoesNothing() async {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 2))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.trackTapped("nope"))
        #expect(playback.played.isEmpty)
    }

    // ALB-15

    @Test func whileTheAlbumLoadsTheScreenSaysSo() async {
        let detail = AlbumDetail.numbered(discs: 1, perDisc: 2)
        let hold = gateway.holdNextAlbumRequest()
        let viewModel = viewModel(detail)

        let load = Task { await viewModel.handleAction(.lifecycle(.viewDidAppear)) }
        for await _ in hold.entered { break }
        #expect(viewModel.phase == .loading)
        hold.release()
        _ = await load.value

        #expect(viewModel.phase == .loaded)
    }

    @Test func aFailedLoadShowsWhyAndRetries() async {
        let detail = AlbumDetail.numbered(discs: 1, perDisc: 2)
        gateway.albumError = .unreachable
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }
        #expect(message.contains("Couldn't reach the server"))

        gateway.albumError = nil
        _ = await viewModel.handleAction(.retry)
        #expect(viewModel.phase == .loaded && viewModel.sections.count == 1)
    }

    @Test func anAlbumWithNoTracksSaysSo() async {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: 1)
        detail.tracks = []
        let viewModel = viewModel(detail)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        #expect(viewModel.phase == .empty && viewModel.sections.isEmpty)
    }

    @Test func aMissingAlbumShowsTheServersMessage() async {
        let viewModel = viewModel(album: Album.numbered(1)[0])
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        guard case .failed(let message) = viewModel.phase else {
            Issue.record("expected failed, got \(viewModel.phase)")
            return
        }
        #expect(message == "The server said: Album not found")
    }

    @Test func signedOutThereIsAMessageAndNoRequest() async {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 1), signedIn: false)
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        #expect(viewModel.phase == .failed("Sign in to see this album.") && gateway.albumRequests.isEmpty)
    }

    @Test func comingBackToTheScreenDoesntReloadALoadedAlbum() async {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 2))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        #expect(gateway.albumRequests.count == 1)
    }

    // The cover

    @Test func theCoverIsFetchedAtTheSizeItIsShownAtAndKeptWhenSmaller() async {
        art.data = png()
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 1))

        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 360))
        #expect(viewModel.cover != nil && art.requests.map(\.pixelSize) == [360])
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 359))
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 180))
        #expect(art.requests.count == 1)

        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 1080))
        #expect(art.requests.map(\.pixelSize) == [360, 1080])
    }

    @Test func aSizeAskedForWhileTheCoverIsFetchingIsFetchedAfterIt() async {
        art.data = png()
        let hold = art.holdNextRequest()
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 1))

        let first = Task { await viewModel.handleAction(.artworkNeeded(pixelSize: 180)) }
        for await _ in hold.entered { break }
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 720))
        hold.release()
        _ = await first.value

        #expect(art.requests.map(\.pixelSize) == [180, 720])
        #expect(viewModel.cover != nil)
    }

    @Test func aSecondAppearanceWhileTheAlbumLoadsDoesntLoadItTwice() async {
        let hold = gateway.holdNextAlbumRequest()
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 2))

        let first = Task { await viewModel.handleAction(.lifecycle(.viewDidAppear)) }
        for await _ in hold.entered { break }
        _ = await viewModel.handleAction(.lifecycle(.viewDidAppear))
        hold.release()
        _ = await first.value

        #expect(gateway.albumRequests.count == 1 && viewModel.phase == .loaded)
    }

    @Test func anAlbumWithoutArtAsksForNone() async {
        art.data = png()
        var album = Album.numbered(1)[0]
        album.coverArtID = nil
        let viewModel = viewModel(album: album)
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 360))
        #expect(viewModel.cover == nil && art.requests.isEmpty)
    }

    @Test func aCoverThatFailsIsAskedForAgain() async {
        let viewModel = viewModel(.numbered(discs: 1, perDisc: 1))
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 360))
        #expect(viewModel.cover == nil)

        art.data = png()
        _ = await viewModel.handleAction(.artworkNeeded(pixelSize: 360))
        #expect(viewModel.cover != nil && art.requests.count == 2)
    }
}
