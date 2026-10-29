import Combine
import SwiftUI
import UIKit

enum LibraryAction: Equatable {
    case lifecycle(LifecycleAction)
    case rowAppeared(Track.ID)
    case artworkNeeded(coverArtID: String, pixelSize: Int)
    case retry
    case refresh
    case trackTapped(Track.ID)
    case settingsTapped
}

/// The library screen: the server's tracks, loaded a page at a time (LIB-1, LIB-2, LIB-4).
final class LibraryViewModel: RoutingViewModel {
    typealias UseCases = HasLibraryUseCase & HasCoverArtUseCase & HasPlaybackUseCase & HasTranscodingUseCase
        & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    enum Route: NavigationRoute {
        case settings

        func destination(context: LibraryViewModel) -> NavigationDestination {
            .sheet(AnyView(SettingsView(viewModel: SettingsViewModel(useCases: context.useCases))))
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    /// Loading the next page starts when a row this close to the end appears.
    static let prefetchDistance = 20
    /// Decoded covers kept for the rows; the oldest go first, and come back when their row does.
    static let artworkLimit = 200

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    @Published private(set) var phase = Phase.loading
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreError: String?
    /// Covers by cover-art ID, at the size the rows show them.
    @Published private(set) var artwork: [String: UIImage] = [:]

    private var requestedArtwork: Set<String> = []
    private var artworkOrder: [String] = []
    private var loadingFirstPage = false

    init(useCases: UseCases) {
        self.useCases = useCases
    }

    func handleAction(_ action: LibraryAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear):
            if tracks.isEmpty { await loadFirstPage() }
        case .retry:
            if phase == .loaded { await loadNextPage() } else { await loadFirstPage() }
        case .rowAppeared(let id):
            guard let index = tracks.firstIndex(where: { $0.id == id }),
                  index >= tracks.count - Self.prefetchDistance,
                  loadMoreError == nil
            else { break }
            await loadNextPage()
        case .artworkNeeded(let coverArtID, let pixelSize):
            await loadArtwork(coverArtID, pixelSize: pixelSize)
        case .refresh:
            await loadFirstPage(keepingListOnScreen: true)
        case .settingsTapped:
            await navigateTo(.settings)
        case .trackTapped(let id):
            // PLAY-1: play it, and queue what follows it in the list.
            if let index = tracks.firstIndex(where: { $0.id == id }) {
                useCases.playbackUseCase.play(tracks, startingAt: index)
            }
        }
        return .none
    }

    /// A pull to refresh keeps the list on screen while it reloads (LIB-3); the system shows its
    /// own spinner at the top.
    private func loadFirstPage(keepingListOnScreen: Bool = false) async {
        guard !loadingFirstPage else { return }
        loadingFirstPage = true
        defer { loadingFirstPage = false }
        if !(keepingListOnScreen && (phase == .loaded || phase == .empty)) { phase = .loading }
        loadMoreError = nil
        do {
            try await useCases.libraryUseCase.loadFirstPage()
            tracks = useCases.libraryUseCase.tracks
            phase = tracks.isEmpty ? .empty : .loaded
        } catch {
            if error.rejectsCredentials { return await reauthenticate() }
            phase = .failed(Self.message(for: error))
        }
    }

    /// SRV-6: the server stopped accepting the saved credentials; back to setup to sign in again.
    private func reauthenticate() async {
        useCases.sessionUseCase.credentialsRejected()
        await useCases.appRouting.navigateToNext(from: .library, with: AppFlowData())
    }

    private func loadNextPage() async {
        guard useCases.libraryUseCase.hasMoreTracks, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        do {
            try await useCases.libraryUseCase.loadNextPage()
            tracks = useCases.libraryUseCase.tracks
        } catch {
            if error.rejectsCredentials { return await reauthenticate() }
            loadMoreError = Self.message(for: error)
        }
    }

    private func loadArtwork(_ coverArtID: String, pixelSize: Int) async {
        guard !requestedArtwork.contains(coverArtID) else { return }
        requestedArtwork.insert(coverArtID)
        // Decoded off the main thread; a failure is forgotten so the row can ask again.
        guard let data = await useCases.coverArtUseCase.coverArt(id: coverArtID, pixelSize: pixelSize),
              let image = await UIImage(data: data)?.byPreparingForDisplay()
        else {
            requestedArtwork.remove(coverArtID)
            return
        }
        artwork[coverArtID] = image
        artworkOrder.append(coverArtID)
        while artworkOrder.count > Self.artworkLimit {
            let oldest = artworkOrder.removeFirst()
            artwork[oldest] = nil
            requestedArtwork.remove(oldest)
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
            message.isEmpty ? "The server couldn't list the tracks." : "The server said: \(message)"
        }
    }
}
