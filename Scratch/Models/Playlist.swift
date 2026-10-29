/// One playlist on the server.
nonisolated struct Playlist: Equatable, Identifiable {
    var id: String
    var name: String
    var owner: String?
    var coverArtID: String?
    var songCount: Int?

    /// Whole seconds, when the server knows it.
    var duration: Int?
}

/// One playlist with its tracks, in the playlist's own order (PLST-7). The same track can be in it
/// more than once.
struct PlaylistDetail: Equatable {
    var playlist: Playlist
    var tracks: [Track]
}
