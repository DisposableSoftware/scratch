import Combine
import Foundation
import SwiftUI
import UIKit

enum AlbumAction: Equatable {
    case lifecycle(LifecycleAction)
    case retry
    case trackTapped(Track.ID)
    case playTapped
    case shuffleTapped
    case artworkNeeded(pixelSize: Int)
}

/// One album's screen (ALB-9 to ALB-15): cover, info, Play, and the tracks by disc.
final class AlbumViewModel: ViewModel {
    typealias UseCases = HasAlbumUseCase & HasCoverArtUseCase & HasPlaybackUseCase & HasSessionUseCase
        & HasAppRoutingUseCase

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    let useCases: UseCases
    /// The album as the grid showed it, which fills the screen in until its tracks arrive.
    let album: Album

    @Published private(set) var phase = Phase.loading
    @Published private(set) var sections: [AlbumSection] = []
    @Published private(set) var details: String
    @Published private(set) var cover: UIImage?

    private var tracks: [Track] = []
    private var loading = false
    private var heldCoverSize = 0
    private var wantedCoverSize = 0
    private var fetchingCover = false

    init(album: Album, useCases: UseCases) {
        self.album = album
        self.useCases = useCases
        details = Self.details(for: album, trackCount: nil)
    }

    func handleAction(_ action: AlbumAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear):
            if phase == .loading || phase == .empty { await load() }
        case .retry:
            await load()
        case .trackTapped(let id):
            // ALB-12: it plays, and what follows it in disc and track order is queued.
            if let index = tracks.firstIndex(where: { $0.id == id }) {
                useCases.playbackUseCase.play(tracks, startingAt: index)
            }
        case .playTapped:
            // ALB-13: from the first track.
            if !tracks.isEmpty { useCases.playbackUseCase.play(tracks, startingAt: 0) }
        case .shuffleTapped:
            // ALB-14: every track once, in a random order.
            if !tracks.isEmpty { useCases.playbackUseCase.playShuffled(tracks) }
        case .artworkNeeded(let pixelSize):
            await loadCover(pixelSize: pixelSize)
        }
        return .none
    }

    private func load() async {
        // A second appearance while the first load runs waits for it.
        guard !loading else { return }
        loading = true
        defer { loading = false }
        phase = .loading
        do {
            guard let detail = try await useCases.albumUseCase.album(id: album.id) else {
                phase = .failed("Sign in to see this album.")
                return
            }
            tracks = detail.tracks.map(\.track)
            details = Self.details(for: detail.album, trackCount: detail.tracks.count)
            sections = Self.sections(for: detail)
            phase = tracks.isEmpty ? .empty : .loaded
        } catch {
            if error.rejectsCredentials { return await reauthenticate() }
            phase = .failed(Self.message(for: error))
        }
    }

    /// ALB-16: the server stopped accepting the saved sign-in; back to setup to sign in again.
    private func reauthenticate() async {
        useCases.sessionUseCase.credentialsRejected()
        await useCases.appRouting.navigateToNext(from: .library, with: AppFlowData())
    }

    /// Fetches the cover at the size the screen shows it. A size about as big as the one held is
    /// kept, a bigger one is fetched again, and one asked for while a fetch runs is fetched after
    /// it. A cover that fails is asked for again the next time the screen reports its size.
    private func loadCover(pixelSize: Int) async {
        guard let id = album.coverArtID else { return }
        wantedCoverSize = max(wantedCoverSize, pixelSize)
        guard !fetchingCover else { return }
        fetchingCover = true
        defer { fetchingCover = false }
        while Double(heldCoverSize) < Double(wantedCoverSize) * 0.95 {
            let target = wantedCoverSize
            guard let data = await useCases.coverArtUseCase.coverArt(id: id, pixelSize: target),
                  let image = await UIImage(data: data)?.byPreparingForDisplay()
            else { return }
            cover = image
            heldCoverSize = target
        }
    }

    // MARK: Presentation

    /// "2000 · Game · 67 songs · 2 hr 1 min", each part only when the server has it (ALB-9).
    private static func details(for album: Album, trackCount: Int?) -> String {
        let count = album.songCount ?? trackCount
        let minutes = album.duration.flatMap { $0 > 0 ? max(1, Int((Double($0) / 60).rounded())) : nil }
        let parts: [String?] = [
            album.year.map { String($0) },
            album.genre.flatMap { $0.isEmpty ? nil : $0 },
            count.map { $0 == 1 ? "1 song" : "\($0) songs" },
            minutes.map { $0 >= 60 ? "\($0 / 60) hr \($0 % 60) min" : "\($0) min" },
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    private static func sections(for detail: AlbumDetail) -> [AlbumSection] {
        let discs = detail.discs
        return discs.map { disc in
            AlbumSection(
                id: disc.number,
                header: discs.count > 1 ? header(for: disc) : nil,
                rows: disc.tracks.map { row(for: $0, albumArtist: detail.album.artist) }
            )
        }
    }

    private static func header(for disc: AlbumDisc) -> String {
        disc.title.map { "Disc \(disc.number) · \($0)" } ?? "Disc \(disc.number)"
    }

    private static func row(for albumTrack: AlbumTrack, albumArtist: String) -> AlbumRow {
        let track = albumTrack.track
        return AlbumRow(
            id: track.id,
            number: albumTrack.number.map(String.init) ?? "",
            title: track.title,
            artist: track.artist.isEmpty || track.artist == albumArtist ? nil : track.artist,
            duration: track.duration.map { Duration.seconds($0).formatted(.time(pattern: .minuteSecond)) }
        )
    }

    private static func message(for error: ServerError) -> String {
        switch error {
        case .unreachable:
            "Couldn't reach the server. Check your connection."
        case .wrongCredentials:
            "The server no longer accepts your username and password."
        case .notSubsonic:
            "The server sent something Scratch couldn't read."
        case .failed(_, let message):
            message.isEmpty ? "The server couldn't load this album." : "The server said: \(message)"
        }
    }
}
