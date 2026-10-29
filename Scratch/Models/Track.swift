/// One song on the server.
struct Track: Equatable, Identifiable {
    var id: String
    var title: String
    var artist: String
    var album: String

    /// Whole seconds, when the server knows it.
    var duration: Int?
    var coverArtID: String?

    /// Whether the user has starred it on the server (LIB-7). Only shown, never changed.
    var isStarred = false
}
