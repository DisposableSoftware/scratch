/// A track as an album lists it: with the disc and the number it has on it.
struct AlbumTrack: Equatable, Identifiable {
    var track: Track

    /// A track the server gives no disc is on disc 1.
    var disc: Int
    var number: Int?

    var id: Track.ID { track.id }
}

/// One disc of an album.
struct AlbumDisc: Equatable, Identifiable {
    var number: Int

    /// The disc's own name, when the server has one.
    var title: String?
    var tracks: [AlbumTrack]

    var id: Int { number }
}

/// One album with its tracks (ALB-9, ALB-10).
struct AlbumDetail: Equatable {
    var album: Album

    /// In disc and track order.
    var tracks: [AlbumTrack]

    /// Disc names by disc number.
    var discTitles: [Int: String]

    /// The tracks grouped by disc, in disc order.
    var discs: [AlbumDisc] {
        Dictionary(grouping: tracks, by: \.disc)
            .sorted { $0.key < $1.key }
            .map { AlbumDisc(number: $0.key, title: discTitles[$0.key], tracks: $0.value) }
    }
}
