import Testing
@testable import Scratch

@Suite(.timeLimit(.minutes(1)))
struct PlaylistUseCaseTests {
    private let gateway = PlaylistGatewayMock()

    private func useCase(signedIn: Bool = true) -> DefaultPlaylistUseCase {
        DefaultPlaylistUseCase(playlistGateway: gateway, sessionState: SessionState(server: signedIn ? .sample : nil))
    }

    // PLST-1

    @Test func playlistsComeByNameWithNumbersReadAsNumbers() async throws {
        gateway.all = [
            Playlist(id: "a", name: "mix 10", owner: nil, coverArtID: nil, songCount: nil, duration: nil),
            Playlist(id: "b", name: "Mix 2", owner: nil, coverArtID: nil, songCount: nil, duration: nil),
            Playlist(id: "c", name: "alpha", owner: nil, coverArtID: nil, songCount: nil, duration: nil),
        ]

        let playlists = try await useCase().playlists()

        #expect(playlists?.map(\.id) == ["c", "b", "a"])
    }

    @Test func signedOutThereIsNothingToLoad() async throws {
        let useCase = useCase(signedIn: false)

        #expect(try await useCase.playlists() == nil)
        #expect(try await useCase.playlist(id: "p1") == nil)
        #expect(gateway.requests == 0 && gateway.detailRequests.isEmpty)
    }

    @Test func aFailureIsThrown() async {
        gateway.error = .unreachable

        await #expect(throws: ServerError.unreachable) { try await useCase().playlists() }
    }

    // PLST-7

    @Test func aPlaylistKeepsTheOrderTheServerGivesItsTracks() async throws {
        var detail = PlaylistDetail.numbered(3)
        detail.tracks.reverse()
        gateway.details["p1"] = detail

        let loaded = try await useCase().playlist(id: "p1")

        #expect(loaded?.tracks.map(\.id) == ["t3", "t2", "t1"])
    }
}
