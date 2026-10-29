import Foundation

/// A track row on the album screen (ALB-11).
struct AlbumRow: Equatable, Identifiable {
    var id: Track.ID
    var number: String
    var title: String

    /// Only when the track's artist isn't the album's.
    var artist: String?
    var duration: String?
}

/// A disc's tracks under its header; a single-disc album has the one section and no header (ALB-10).
struct AlbumSection: Equatable, Identifiable {
    var id: Int
    var header: String?
    var rows: [AlbumRow]
}
