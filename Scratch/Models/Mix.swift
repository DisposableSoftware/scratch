/// The kinds of mix the Me tab makes, in the order it lists them (MIX-2).
nonisolated enum MixKind: String, CaseIterable, Identifiable {
    case hearts
    case mostPlayed
    case onThisDay

    var id: String { rawValue }

    /// The name a mix has when the model doesn't name it (MIX-8).
    var defaultName: String {
        switch self {
        case .hearts: "Hearts"
        case .mostPlayed: "Most played"
        case .onThisDay: "On this day"
        }
    }

    /// The description a mix has when the model doesn't write one (MIX-8).
    var defaultDescription: String {
        switch self {
        case .hearts: "Songs you've hearted."
        case .mostPlayed: "The songs you play the most."
        case .onThisDay: "Albums released on this day."
        }
    }
}

/// A queue made on the device from a shortlist of tracks (MIX-2).
struct Mix: Equatable, Identifiable {
    var kind: MixKind
    var name: String
    var description: String
    var tracks: [Track]

    var id: MixKind { kind }
}
