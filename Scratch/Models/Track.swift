/// One song on the server.
struct Track: Equatable, Identifiable {
    var id: String
    var title: String
    var artist: String
    var album: String

    /// Whole seconds, when the server knows it.
    var duration: Int?
    var coverArtID: String?
}
