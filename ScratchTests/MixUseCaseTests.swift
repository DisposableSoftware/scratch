import Foundation
import Testing
@testable import Scratch

@Suite(.timeLimit(.minutes(1)))
struct MixUseCaseTests {
    private let gateway = AlbumGatewayMock()
    private let model = MixModelGatewayMock()
    private let mixes = MixesState()

    /// Thursday 29 October 2026, in UTC.
    private static let today = Date(timeIntervalSince1970: 1_793_275_200)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        return calendar
    }

    private func useCase(signedIn: Bool = true) -> DefaultMixUseCase {
        DefaultMixUseCase(albumGateway: gateway, modelGateway: model, sessionState: SessionState(server: signedIn ? .sample : nil), mixesState: mixes, now: { Self.today }, calendar: calendar)
    }

    /// Tracks with play counts, for Most played.
    private func played(_ counts: [Int], prefix: String = "p") -> AlbumDetail {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: counts.count)
        detail.tracks = zip(detail.tracks, counts).enumerated().map { index, pair in
            var track = pair.0
            track.track.id = "\(prefix)\(index)"
            track.track.playCount = pair.1

            return track
        }

        return detail
    }

    // MIX-5: Hearts

    @Test func heartsAreBuiltFromTheStarredTracksAndAskedOfTheModelNumbered() async throws {
        gateway.starredTrackList = Track.numbered(3)
        let useCase = useCase()

        try await useCase.makeMixes()

        #expect(mixes.mixes.map(\.kind) == [.hearts])
        #expect(model.asked.first?.kind == .hearts && model.asked.first?.shortlist.map(\.id) == ["t0", "t1", "t2"])
        #expect(model.asked.first?.limit == 25)
    }

    @Test func aShortlistHoldsAtMostSixtyTracks() async throws {
        gateway.starredTrackList = Track.numbered(100)

        try await useCase().makeMixes()

        #expect(model.asked.first?.shortlist.count == 60)
    }

    // MIX-5: Most played

    @Test func mostPlayedComesFromTheFrequentAlbumsByPlayCount() async throws {
        gateway.frequent = Album.numbered(3)
        gateway.details["a0"] = played([5, 0, 9], prefix: "x")
        gateway.details["a1"] = played([7], prefix: "y")
        gateway.details["a2"] = played([1], prefix: "z")

        try await useCase().makeMixes()

        let shortlist = try #require(model.asked.first { $0.kind == .mostPlayed }).shortlist

        #expect(shortlist.map(\.id) == ["x2", "y0", "x0", "z0"])
        #expect(gateway.frequentRequests == [10])
    }

    @Test func equalPlayCountsKeepTheServersOrder() async throws {
        gateway.frequent = Album.numbered(1)
        gateway.details["a0"] = played([4, 4, 4])

        try await useCase().makeMixes()

        #expect(model.asked.first?.shortlist.map(\.id) == ["p0", "p1", "p2"])
    }

    // MIX-5: On this day

    @Test func onThisDayTakesTheAlbumsReleasedOnTodaysMonthAndDay() async throws {
        var albums = Album.numbered(5)
        albums[1].releaseMonth = 10
        albums[1].releaseDay = 29
        albums[3].releaseMonth = 10
        albums[3].releaseDay = 28
        albums[4].releaseMonth = 11
        albums[4].releaseDay = 29
        gateway.all = albums
        gateway.details["a1"] = .numbered(discs: 1, perDisc: 2, id: "a1")

        try await useCase().makeMixes()

        let asked = try #require(model.asked.first { $0.kind == .onThisDay })

        #expect(mixes.mixes.map(\.kind) == [.onThisDay])
        #expect(asked.shortlist.count == 2)
        #expect(gateway.albumRequests == ["a1"])
    }

    @Test func theAlbumScanStopsAfterTwentyPages() async throws {
        gateway.all = Album.numbered(2100)

        try await useCase().makeMixes()

        #expect(gateway.requests.count == 20)
        #expect(mixes.mixes.isEmpty)
    }

    @Test func theAlbumScanStopsAtAShortPage() async throws {
        gateway.all = Album.numbered(150)

        try await useCase().makeMixes()

        #expect(gateway.requests.map(\.offset) == [0, 100])
    }

    // The mixes

    // MIX-14: Genre

    @Test func genreTakesTheMostCommonGenreOfHeartsAndPlaysAndTheTracksOfItsAlbums() async throws {
        var starred = Track.numbered(3)
        starred[0].genre = "Jazz"
        starred[1].genre = "Rock"
        starred[2].genre = "Rock"
        gateway.starredTrackList = starred
        gateway.genreAlbums["Rock"] = Album.numbered(2)
        gateway.details["a0"] = played([0, 0], prefix: "g")
        gateway.details["a1"] = played([0], prefix: "h")

        try await useCase().makeMixes()

        let asked = try #require(model.asked.first { $0.kind == .genre })

        #expect(gateway.genreRequests == ["Rock"])
        #expect(asked.shortlist.map(\.id) == ["g0", "g1", "h0"])
    }

    @Test func genreTiesGoToTheGenreMetFirst() async throws {
        var starred = Track.numbered(2)
        starred[0].genre = "Jazz"
        starred[1].genre = "Rock"
        gateway.starredTrackList = starred

        try await useCase().makeMixes()

        #expect(gateway.genreRequests == ["Jazz"])
    }

    @Test func genreHasNoCardWhenNoTrackHasAGenre() async throws {
        gateway.starredTrackList = Track.numbered(2)

        try await useCase().makeMixes()

        #expect(gateway.genreRequests.isEmpty)
        #expect(mixes.mixes.map(\.kind) == [.hearts])
    }

    // MIX-15: Discover

    @Test func discoverTakesTheTracksOfRandomAlbumsLeastPlayedFirst() async throws {
        gateway.randomList = Album.numbered(2)
        gateway.details["a0"] = played([4, 0, 2], prefix: "d")
        gateway.details["a1"] = played([0, 9], prefix: "e")

        try await useCase().makeMixes()

        let asked = try #require(model.asked.first { $0.kind == .discover })

        #expect(mixes.mixes.map(\.kind) == [.discover])
        #expect(asked.shortlist.map(\.id) == ["d1", "e0", "d2", "d0", "e1"])
    }

    @Test func discoverHasNoCardWithoutRandomAlbums() async throws {
        try await useCase().makeMixes()

        #expect(mixes.mixes.isEmpty)
    }

    @Test func mixesComeInTheOrderHeartsMostPlayedGenreDiscoverOnThisDay() async throws {
        var starred = Track.numbered(2)
        starred[0].genre = "Rock"
        gateway.starredTrackList = starred
        gateway.genreAlbums["Rock"] = Album.numbered(1)
        gateway.randomList = Album.numbered(1)
        gateway.frequent = Album.numbered(1)
        gateway.details["a0"] = played([0])
        var albums = Album.numbered(1)
        albums[0].releaseMonth = 10
        albums[0].releaseDay = 29
        gateway.all = albums
        gateway.details["a0"] = played([0, 3])

        try await useCase().makeMixes()

        #expect(mixes.mixes.map(\.kind) == [.hearts, .mostPlayed, .genre, .discover, .onThisDay])
    }

    @Test func aMixWithNoShortlistHasNoCard() async throws {
        try await useCase().makeMixes()

        #expect(mixes.mixes.isEmpty && model.asked.isEmpty)
    }

    // MIX-6

    @Test func theModelsPicksAreTheMixInItsOrderWithItsNameAndLine() async throws {
        gateway.starredTrackList = Track.numbered(4)
        model.answer = { _, _, _ in MixCuration(name: "  Late night  ", description: "Slow ones. ", picks: [3, 1]) }

        try await useCase().makeMixes()

        let mix = try #require(mixes.mixes.first)

        #expect(mix.tracks.map(\.id) == ["t2", "t0"])
        #expect(mix.name == "Late night" && mix.description == "Slow ones.")
    }

    @Test func aMixHoldsAtMostTwentyFiveTracks() async throws {
        gateway.starredTrackList = Track.numbered(60)
        model.answer = { _, _, _ in MixCuration(name: "Big", description: "Many.", picks: Array(1...60)) }

        try await useCase().makeMixes()

        #expect(mixes.mixes.first?.tracks.count == 25)
    }

    // MIX-7

    @Test func numbersOutsideTheShortlistAreDroppedAndRepeatsKeptOnce() async throws {
        gateway.starredTrackList = Track.numbered(3)
        model.answer = { _, _, _ in MixCuration(name: "N", description: "D", picks: [5, 0, 2, 2, -1, 99, 3, 2]) }

        try await useCase().makeMixes()

        #expect(mixes.mixes.first?.tracks.map(\.id) == ["t1", "t2"])
    }

    // MIX-8

    @Test func aFailingModelGivesTheRulesOwnMix() async throws {
        gateway.starredTrackList = Track.numbered(40)
        model.answer = { _, _, _ in throw ModelFailure() }

        try await useCase().makeMixes()

        let mix = try #require(mixes.mixes.first)

        #expect(mix.name == "Hearts" && mix.description == MixKind.hearts.defaultDescription)
        #expect(mix.tracks.map(\.id) == Track.numbered(25).map(\.id))
    }

    @Test func aModelThatPicksNothingUsableGivesTheRulesOwnMix() async throws {
        gateway.starredTrackList = Track.numbered(3)
        model.answer = { _, _, _ in MixCuration(name: "N", description: "D", picks: [0, 9]) }

        try await useCase().makeMixes()

        #expect(mixes.mixes.first?.name == "Hearts" && mixes.mixes.first?.tracks.count == 3)
    }

    @Test func aBlankNameOrLineIsTheRulesOwn() async throws {
        gateway.starredTrackList = Track.numbered(2)
        model.answer = { _, _, _ in MixCuration(name: " ", description: "", picks: [1]) }

        try await useCase().makeMixes()

        #expect(mixes.mixes.first?.name == "Hearts" && mixes.mixes.first?.description == MixKind.hearts.defaultDescription)
        #expect(mixes.mixes.first?.tracks.count == 1)
    }

    @Test func anUnavailableModelIsNotAskedAndGivesTheRulesOwnMix() async throws {
        gateway.starredTrackList = Track.numbered(2)
        model.isAvailable = false

        try await useCase().makeMixes()

        #expect(model.asked.isEmpty && mixes.mixes.first?.name == "Hearts")
    }

    // MIX-3, MIX-4

    @Test func eachMixLandsAsItIsReadyTheFirstTime() async throws {
        gateway.starredTrackList = Track.numbered(2)
        gateway.frequent = Album.numbered(1)
        gateway.details["a0"] = played([3])
        var seen: [[MixKind]] = []
        model.answer = { [mixes] kind, shortlist, _ in
            seen.append(mixes.mixes.map(\.kind))

            return MixCuration(name: "N", description: "D", picks: [1])
        }

        try await useCase().makeMixes()

        #expect(seen == [[], [.hearts]])
    }

    @Test func aLaterMakingKeepsTheOldMixesUntilTheNewOnesReplaceThem() async throws {
        gateway.starredTrackList = Track.numbered(2)
        let useCase = useCase()
        try await useCase.makeMixes()
        gateway.starredTrackList = Track.numbered(3)
        var seen: [Int] = []
        model.answer = { [mixes] _, _, _ in
            seen.append(mixes.mixes.first?.tracks.count ?? -1)

            return MixCuration(name: "N", description: "D", picks: [1, 2, 3])
        }

        try await useCase.makeMixes()

        #expect(seen == [2] && mixes.mixes.first?.tracks.count == 3)
    }

    // Errors and the session

    @Test func aServerErrorIsThrownAndLeavesTheOldMixes() async throws {
        gateway.starredTrackList = Track.numbered(2)
        let useCase = useCase()
        try await useCase.makeMixes()
        gateway.starredTracksError = .unreachable

        await #expect(throws: ServerError.unreachable) { try await useCase.makeMixes() }
        #expect(mixes.mixes.count == 1)
    }

    @Test func signedOutNothingIsRequested() async throws {
        gateway.starredTrackList = Track.numbered(2)

        try await useCase(signedIn: false).makeMixes()

        #expect(mixes.mixes.isEmpty && model.asked.isEmpty)
    }

    // MIX-1

    @Test func theStateFollowsTheModelsAvailability() {
        let useCase = useCase()

        #expect(!mixes.isModelAvailable)
        useCase.refreshAvailability()

        #expect(mixes.isModelAvailable)
        model.isAvailable = false
        useCase.refreshAvailability()

        #expect(!mixes.isModelAvailable)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct MixUseCaseRaceTests {
    private let gateway = AlbumGatewayMock()
    private let model = MixModelGatewayMock()
    private let mixes = MixesState()
    private let session = SessionState(server: .sample)

    // MIX-9: a sign-out while the model is working drops what it made.
    @Test func mixesMadeAfterASignOutAreNotKept() async throws {
        gateway.starredTrackList = Track.numbered(3)
        let useCase = DefaultMixUseCase(albumGateway: gateway, modelGateway: model, sessionState: session, mixesState: mixes)
        model.answer = { [session] _, _, _ in
            session.server = nil

            return MixCuration(name: "N", description: "D", picks: [1])
        }

        try await useCase.makeMixes()

        #expect(mixes.mixes.isEmpty)
    }

    @Test func aCancelledMakingKeepsTheOldMixes() async throws {
        gateway.starredTrackList = Track.numbered(3)
        let useCase = DefaultMixUseCase(albumGateway: gateway, modelGateway: model, sessionState: session, mixesState: mixes)
        try await useCase.makeMixes()
        let old = mixes.mixes
        model.answer = { _, _, _ in throw CancellationError() }

        let making = Task { try await useCase.makeMixes() }
        making.cancel()
        try await making.value

        #expect(mixes.mixes == old)
    }
}
