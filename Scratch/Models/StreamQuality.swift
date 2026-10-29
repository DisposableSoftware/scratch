/// What to ask the server for on a `stream` request (TRANS-1, TRANS-2).
nonisolated struct StreamQuality: Equatable, Codable {
    enum Format: String, Codable, CaseIterable {
        /// The file as stored.
        case original = "raw"
        case mp3
        case aac
    }

    static let bitRates = [320, 256, 192, 128, 96, 64]

    var format: Format {
        didSet { if format == .original { maxBitRate = nil } }
    }
    /// kbps; nil means no limit. Always nil for Original, which the server can't cap (TRANS-2).
    var maxBitRate: Int? {
        didSet { if format == .original { maxBitRate = nil } }
    }

    init(format: Format, maxBitRate: Int?) {
        self.format = format
        self.maxBitRate = format == .original ? nil : maxBitRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decode(Format.self, forKey: .format),
            maxBitRate: try container.decodeIfPresent(Int.self, forKey: .maxBitRate)
        )
    }
}

/// Which network a track starts on (TRANS-3).
nonisolated enum NetworkKind: Equatable {
    case wifi
    case cellular
}

/// The quality per network, as the user set it (TRANS-3, TRANS-5).
nonisolated struct TranscodingSettings: Equatable, Codable {
    var wifi: StreamQuality
    var cellular: StreamQuality

    static let defaults = TranscodingSettings(
        wifi: StreamQuality(format: .original, maxBitRate: nil),
        cellular: StreamQuality(format: .mp3, maxBitRate: 192)
    )

    func quality(on network: NetworkKind) -> StreamQuality {
        switch network {
        case .wifi: wifi
        case .cellular: cellular
        }
    }
}
