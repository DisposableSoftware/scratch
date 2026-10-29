import Combine
import SwiftUI
import UIKit

enum PlaylistsAction: Equatable {
    case lifecycle(LifecycleAction)
    case artworkNeeded(coverArtID: String, pixelSize: Int)
    case retry
    case refresh
    case playlistTapped(Playlist.ID)
    case settingsTapped
}

/// The Playlists tab: the server's playlists in a grid (PLST-1 to PLST-6).
final class PlaylistsViewModel: RoutingViewModel {
    typealias UseCases = HasPlaylistUseCase & HasCoverArtUseCase & HasPlaybackUseCase & HasTranscodingUseCase
        & HasDisplayUseCase & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    enum Route: NavigationRoute {
        case settings

        /// PLST-6: the playlist's screen, pushed onto the tab's stack.
        case playlist(Playlist)

        func destination(context: PlaylistsViewModel) -> NavigationDestination {
            switch self {
            case .settings:
                SettingsViewModel.destination(useCases: context.useCases)
            case .playlist(let playlist):
                .push(key: "playlist:\(playlist.id)", AnyView(PlaylistView(viewModel: PlaylistViewModel(playlist: playlist, useCases: context.useCases))))
            }
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    /// Decoded covers kept for the cells; the oldest go first, and come back when their cell does.
    static let artworkLimit = 300

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    @Published private(set) var phase = Phase.loading
    @Published private(set) var playlists: [Playlist] = []

    /// The columns in the grid: the albums per row setting, which the grid follows at once (PLST-2).
    @Published private(set) var columns = AlbumsPerRow.default

    /// Covers by cover-art ID, at the size the cells show them.
    @Published private(set) var artwork: [String: UIImage] = [:]

    private var artworkOrder: [String] = []
    private var heldArtworkSize: [String: Int] = [:]
    private var wantedArtworkSize: [String: Int] = [:]
    private var fetchingArtwork: Set<String> = []
    private var loading = false

    init(useCases: UseCases) {
        self.useCases = useCases
        useCases.displayUseCase.state.$albumsPerRow.assign(to: &$columns)
    }

    func handleAction(_ action: PlaylistsAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear):
            if playlists.isEmpty { await load() }
        case .retry:
            await load()
        case .refresh:
            await load(keepingGridOnScreen: true)
        case .artworkNeeded(let coverArtID, let pixelSize):
            await loadArtwork(coverArtID, pixelSize: pixelSize)
        case .playlistTapped(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                await navigateTo(.playlist(playlist))
            }

        case .settingsTapped:
            await navigateTo(.settings)
        }

        return .none
    }

    /// A pull to refresh keeps the grid on screen while it reloads (PLST-4).
    private func load(keepingGridOnScreen: Bool = false) async {
        guard !loading else { return }

        loading = true
        defer { loading = false }
        if !(keepingGridOnScreen && (phase == .loaded || phase == .empty)) { phase = .loading }

        do {
            guard let loaded = try await useCases.playlistUseCase.playlists() else {
                phase = .failed("Sign in to see your playlists.")
                return
            }

            playlists = loaded
            phase = loaded.isEmpty ? .empty : .loaded
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

    /// Fetches a cover at the size a cell wants, as the Albums grid does (PLST-5).
    private func loadArtwork(_ coverArtID: String, pixelSize: Int) async {
        wantedArtworkSize[coverArtID] = max(wantedArtworkSize[coverArtID] ?? 0, pixelSize)
        guard !fetchingArtwork.contains(coverArtID) else { return }

        fetchingArtwork.insert(coverArtID)
        defer { fetchingArtwork.remove(coverArtID) }

        while let target = wantedArtworkSize[coverArtID] {
            if let held = heldArtworkSize[coverArtID], Double(held) >= Double(target) * 0.95 { return }

            guard let data = await useCases.coverArtUseCase.coverArt(id: coverArtID, pixelSize: target),
                  let image = await UIImage(data: data)?.byPreparingForDisplay()
            else { return }
            artwork[coverArtID] = image
            heldArtworkSize[coverArtID] = target
            if !artworkOrder.contains(coverArtID) { artworkOrder.append(coverArtID) }

            while artworkOrder.count > Self.artworkLimit {
                let oldest = artworkOrder.removeFirst()
                artwork[oldest] = nil
                heldArtworkSize[oldest] = nil
                wantedArtworkSize[oldest] = nil
            }
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
            message.isEmpty ? "The server couldn't list the playlists." : "The server said: \(message)"
        }
    }
}
