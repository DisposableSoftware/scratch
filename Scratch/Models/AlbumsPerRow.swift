/// How many albums the grid shows in a row (ALB-17).
nonisolated enum AlbumsPerRow {
    static let range = 1...5
    static let `default` = 2

    /// Anything outside the range, as a saved value from elsewhere might be, is brought into it.
    static func clamped(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
