import Testing
@testable import Scratch

struct AlbumDetailTests {
    @Test func tracksGroupByDiscInDiscOrderWithTheirTitles() {
        let detail = AlbumDetail.numbered(discs: 3, perDisc: 2, titles: [1: "Opening", 3: "Change"])

        let discs = detail.discs

        #expect(discs.map(\.number) == [1, 2, 3])
        #expect(discs.map(\.title) == ["Opening", nil, "Change"])
        #expect(discs.map { $0.tracks.map(\.id) } == [["d1t1", "d1t2"], ["d2t1", "d2t2"], ["d3t1", "d3t2"]])
    }

    @Test func aSingleDiscIsOneGroup() {
        #expect(AlbumDetail.numbered(discs: 1, perDisc: 4).discs.count == 1)
    }

    @Test func noTracksMeansNoDiscs() {
        var detail = AlbumDetail.numbered(discs: 1, perDisc: 1)
        detail.tracks = []
        #expect(detail.discs.isEmpty)
    }

    @Test func discsKeepTheTracksInTheOrderGiven() {
        var detail = AlbumDetail.numbered(discs: 2, perDisc: 3)
        detail.tracks = detail.tracks.reversed()
        #expect(detail.discs.map(\.number) == [1, 2])
        #expect(detail.discs[0].tracks.map(\.id) == ["d1t3", "d1t2", "d1t1"])
    }
}
