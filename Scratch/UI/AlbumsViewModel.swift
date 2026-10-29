import Combine
import SwiftUI
import UIKit

enum AlbumsAction: Equatable {
    case lifecycle(LifecycleAction)
    case albumAppeared(Album.ID)
    case artworkNeeded(coverArtID: String, pixelSize: Int)
    case retry
    case refresh
    case albumTapped(Album.ID)
    case settingsTapped
}

/// The Albums tab: the server's albums in a grid, a page at a time (ALB-2, ALB-4, ALB-6, ALB-7).
final class AlbumsViewModel: RoutingViewModel {
    typealias UseCases = HasAlbumUseCase & HasCoverArtUseCase & HasPlaybackUseCase & HasTranscodingUseCase
        & HasDisplayUseCase & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    enum Route: NavigationRoute {
        case settings

        /// ALB-8: the album's screen, pushed onto the tab's stack.
        case album(Album)

        func destination(context: AlbumsViewModel) -> NavigationDestination {
            switch self {
            case .settings:
                SettingsViewModel.destination(useCases: context.useCases)
            case .album(let album):
                .push(key: "album:\(album.id)", AnyView(AlbumView(viewModel: AlbumViewModel(album: album, useCases: context.useCases))))
            }
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    /// The next page starts loading when an album this close to the end appears.
    static let prefetchDistance = 20

    /// Decoded covers kept for the cells; the oldest go first, and come back when their cell does.
    static let artworkLimit = 300

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    @Published private(set) var phase = Phase.loading

    /// The starred albums, shown above the rest (ALB-3).
    @Published private(set) var favourites: [Album] = []

    /// The other albums.
    @Published private(set) var albums: [Album] = []

    /// The columns in the grid: the albums per row setting, which the grid follows at once.
    @Published private(set) var columns = AlbumsPerRow.default
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreError: String?
    /// Covers by cover-art ID, at the size the cells show them.
    @Published private(set) var artwork: [String: UIImage] = [:]

    private var artworkOrder: [String] = []
    private var heldArtworkSize: [String: Int] = [:]

    /// The largest size a cell has asked for, per cover.
    private var wantedArtworkSize: [String: Int] = [:]
    private var fetchingArtwork: Set<String> = []
    private var loadingFirstPage = false

    init(useCases: UseCases) {
        self.useCases = useCases
        useCases.displayUseCase.state.$albumsPerRow.assign(to: &$columns)
    }

    func handleAction(_ action: AlbumsAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear):
            if albums.isEmpty && favourites.isEmpty { await loadFirstPage() }
        case .retry:
            if phase == .loaded { await loadNextPage() } else { await loadFirstPage() }
        case .refresh:
            await loadFirstPage(keepingGridOnScreen: true)
        case .albumAppeared(let id):
            guard albums.suffix(Self.prefetchDistance).contains(where: { $0.id == id }), loadMoreError == nil else { break }

            await loadNextPage()

        case .artworkNeeded(let coverArtID, let pixelSize):
            await loadArtwork(coverArtID, pixelSize: pixelSize)
        case .albumTapped(let id):
            if let album = (favourites + albums).first(where: { $0.id == id }) {
                await navigateTo(.album(album))
            }

        case .settingsTapped:
            await navigateTo(.settings)
        }

        return .none
    }

    /// A pull to refresh keeps the grid on screen while it reloads (ALB-5); the system shows its
    /// own spinner at the top.
    private func loadFirstPage(keepingGridOnScreen: Bool = false) async {
        guard !loadingFirstPage else { return }

        loadingFirstPage = true
        defer { loadingFirstPage = false }
        if !(keepingGridOnScreen && (phase == .loaded || phase == .empty)) { phase = .loading }

        // A next page still out from before is dropped when it lands, so its footer goes now.
        isLoadingMore = false
        loadMoreError = nil

        do {
            try await useCases.albumUseCase.loadFirstPage()
            favourites = useCases.albumUseCase.favourites
            albums = useCases.albumUseCase.albums
            phase = albums.isEmpty && favourites.isEmpty ? .empty : .loaded
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

    private func loadNextPage() async {
        guard useCases.albumUseCase.hasMoreAlbums, !isLoadingMore else { return }

        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }

        do {
            try await useCases.albumUseCase.loadNextPage()
            albums = useCases.albumUseCase.albums
        } catch {
            if error.rejectsCredentials { return await reauthenticate() }

            loadMoreError = Self.message(for: error)
        }
    }

    /// Fetches a cover at the size a cell wants. A cover already held at about that size or larger
    /// is kept; a larger one is fetched again, and a size asked for while a fetch runs is fetched
    /// after it. A cover that fails is asked for again the next time its cell reports its size.
    private func loadArtwork(_ coverArtID: String, pixelSize: Int) async {
        wantedArtworkSize[coverArtID] = max(wantedArtworkSize[coverArtID] ?? 0, pixelSize)
        guard !fetchingArtwork.contains(coverArtID) else { return }

        fetchingArtwork.insert(coverArtID)
        defer { fetchingArtwork.remove(coverArtID) }

        while let target = wantedArtworkSize[coverArtID] {
            // Cells at a pixel's difference from each other don't ask for a second copy.
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
            message.isEmpty ? "The server couldn't list the albums." : "The server said: \(message)"
        }
    }
}
