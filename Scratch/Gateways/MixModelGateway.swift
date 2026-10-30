import Foundation
import FoundationModels

/// What the on-device model made of a shortlist (MIX-6): a name, a description, and the numbers of
/// the tracks it chose, from 1 in the shortlist, in the order to play them. Nothing here is
/// checked: the use case drops what isn't a position in the shortlist (MIX-7).
struct MixCuration: Equatable {
    var name: String
    var description: String
    var picks: [Int]
}

/// The language model on the device.
protocol MixModelGateway {
    /// Whether the model can be asked now.
    var isAvailable: Bool { get }

    /// Asks the model for the tracks of `shortlist` that fit `kind`'s mix, at most `limit`.
    func curate(kind: MixKind, shortlist: [Track], limit: Int) async throws -> MixCuration
}

final class OnDeviceMixModelGateway: MixModelGateway {
    var isAvailable: Bool { SystemLanguageModel.default.availability == .available }

    func curate(kind: MixKind, shortlist: [Track], limit: Int) async throws -> MixCuration {
        let session = LanguageModelSession(instructions: Self.instructions(for: kind, limit: limit))
        let response = try await session.respond(to: Self.prompt(for: shortlist), generating: MixDraft.self)

        return MixCuration(name: response.content.name, description: response.content.blurb, picks: response.content.picks)
    }

    private static func instructions(for kind: MixKind, limit: Int) -> String {
        let theme = switch kind {
        case .hearts: "songs the listener has hearted"
        case .mostPlayed: "the songs the listener plays the most"
        case .genre: "songs of the genre the listener plays and hearts the most"
        case .discover: "songs the listener has not played yet"
        case .onThisDay: "songs from albums released on this day of the year"
        }

        return """
        You make a playlist for a music listener from a numbered list of their songs: \(theme). \
        Choose at most \(limit) songs that sit well together and put them in the order to play them, \
        with a flow from start to finish. Answer with the numbers of the songs from the list. \
        Give the playlist a short name and one sentence describing it.
        """
    }

    /// One short line per track, numbered from 1.
    static func prompt(for shortlist: [Track]) -> String {
        shortlist.enumerated().map { index, track in
            let details = [track.album, track.year.map(String.init), track.genre].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")

            return "\(index + 1). \(track.title) by \(track.artist)" + (details.isEmpty ? "" : " (\(details))")
        }.joined(separator: "\n")
    }
}

@Generable
private struct MixDraft {
    @Guide(description: "A short name for the playlist, a few words")
    var name: String

    @Guide(description: "One sentence about the playlist")
    var blurb: String

    @Guide(description: "The numbers of the chosen songs, in the order to play them")
    var picks: [Int]
}
