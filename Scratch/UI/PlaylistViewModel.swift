import Combine
import Foundation
import SwiftUI
import UIKit

enum PlaylistAction: Equatable {
    case lifecycle(LifecycleAction)
    case retry

    /// The track at this place in the playlist, from 0.
    case trackTapped(Int)
    case playTapped
    case shuffleTapped
    case artworkNeeded(pixelSize: Int)
}

/// One playlist's screen (PLST-7 to PLST-11): cover, info, Play, and the tracks in order.
final class PlaylistViewModel: ViewModel {
    typealias UseCases = HasPlaylistUseCase & HasCoverArtUseCase & HasPlaybackUseCase & HasSessionUseCase
        & HasAppRoutingUseCase

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    let useCases: UseCases

    /// The playlist as the grid showed it, which fills the screen in until its tracks arrive.
    let playlist: Playlist

    @Published private(set) var phase = Phase.loading
    @Published private(set) var rows: [PlaylistRow] = []
    @Published private(set) var details: String
    @Published private(set) var cover: UIImage?

    private var tracks: [Track] = []
    private var loading = false
    private var heldCoverSize = 0
    private var wantedCoverSize = 0
    private var fetchingCover = false

    init(playlist: Playlist, useCases: UseCases) {
        self.playlist = playlist
        self.useCases = useCases
        details = Self.details(for: playlist, trackCount: nil)
    }

    func handleAction(_ action: PlaylistAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear):
            if phase == .loading || phase == .empty { await load() }
        case .retry:
            await load()
        case .trackTapped(let index):
            // PLST-8: it plays, and what follows it in the playlist is queued.
            if tracks.indices.contains(index) { useCases.playbackUseCase.play(tracks, startingAt: index) }

        case .playTapped:
            if !tracks.isEmpty { useCases.playbackUseCase.play(tracks, startingAt: 0) }
        case .shuffleTapped:
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
            guard let detail = try await useCases.playlistUseCase.playlist(id: playlist.id) else {
                phase = .failed("Sign in to see this playlist.")
                return
            }

            tracks = detail.tracks
            details = Self.details(for: detail.playlist, trackCount: detail.tracks.count)
            rows = Self.rows(for: detail.tracks)
            phase = tracks.isEmpty ? .empty : .loaded
        } catch {
            if error.rejectsCredentials { return await reauthenticate() }

            phase = .failed(Self.message(for: error))
        }
    }

    /// PLST-11: the server stopped accepting the saved sign-in; back to setup to sign in again.
    private func reauthenticate() async {
        useCases.sessionUseCase.credentialsRejected()
        await useCases.appRouting.navigateToNext(from: .library, with: AppFlowData())
    }

    /// Fetches the cover at the size the screen shows it, as the album screen does.
    private func loadCover(pixelSize: Int) async {
        guard let id = playlist.coverArtID else { return }

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

    /// "Weston · 12 songs · 1 hr 11 min", each part only when the server has it (PLST-7).
    private static func details(for playlist: Playlist, trackCount: Int?) -> String {
        let count = playlist.songCount ?? trackCount
        let minutes = playlist.duration.flatMap { $0 > 0 ? max(1, Int((Double($0) / 60).rounded())) : nil }
        let parts: [String?] = [
            playlist.owner,
            count.map { $0 == 1 ? "1 song" : "\($0) songs" },
            minutes.map { $0 >= 60 ? "\($0 / 60) hr \($0 % 60) min" : "\($0) min" },
        ]

        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    static func rows(for tracks: [Track]) -> [PlaylistRow] {
        tracks.enumerated().map { index, track in
            PlaylistRow(id: index, line: AlbumRow(
                id: track.id,
                number: String(index + 1),
                title: track.title,
                artist: track.artist.isEmpty ? nil : track.artist,
                duration: track.duration.map { Duration.seconds($0).formatted(.time(pattern: .minuteSecond)) },
                isStarred: track.isStarred
            ))
        }
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
            message.isEmpty ? "The server couldn't load this playlist." : "The server said: \(message)"
        }
    }
}
