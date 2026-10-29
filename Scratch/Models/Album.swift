/// One album on the server.
nonisolated struct Album: Equatable, Identifiable {
    var id: String
    var name: String
    var artist: String
    var coverArtID: String?
    var songCount: Int?
    /// Whole seconds, when the server knows it.
    var duration: Int?
    var year: Int?
    var genre: String?
    /// Whether the user has starred it on the server (ALB-3).
    var isStarred: Bool

    /// The month and day the album was released, when the server has them (MIX-5).
    var releaseMonth: Int?
    var releaseDay: Int?
}
