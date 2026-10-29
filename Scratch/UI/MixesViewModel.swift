import Combine
import SwiftUI
import UIKit

enum MixesAction: Equatable {
    case lifecycle(LifecycleAction)
    case artworkNeeded(coverArtID: String, pixelSize: Int)
    case retry
    case refresh
    case mixTapped(MixKind)
    case settingsTapped
}

/// The Me tab: the mixes the device made (MIX-2 to MIX-4).
final class MixesViewModel: RoutingViewModel {
    typealias UseCases = HasMixUseCase & HasCoverArtUseCase & HasPlaybackUseCase & HasTranscodingUseCase
        & HasDisplayUseCase & HasSessionUseCase & HasAppRoutingUseCase & HasCoordinator

    enum Route: NavigationRoute {
        case settings

        /// MIX-10: the mix's screen, pushed onto the tab's stack.
        case mix(Mix)

        func destination(context: MixesViewModel) -> NavigationDestination {
            switch self {
            case .settings:
                SettingsViewModel.destination(useCases: context.useCases)
            case .mix(let mix):
                .push(key: "mix:\(mix.kind.rawValue)", AnyView(MixView(viewModel: MixViewModel(mix: mix, useCases: context.useCases))))
            }
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    /// Decoded covers kept for the cards; the oldest go first, and come back when their card does.
    static let artworkLimit = 30

    let useCases: UseCases
    var coordinator: Coordinator { useCases.coordinator }

    @Published private(set) var phase = Phase.loading

    /// The mixes made so far, which the state keeps until they are made again (MIX-9).
    @Published private(set) var mixes: [Mix] = []

    /// Whether the mixes are being made now: the cards so far show with a progress indicator.
    @Published private(set) var isMaking = false

    /// Covers by cover-art ID, at the size the cards show them.
    @Published private(set) var artwork: [String: UIImage] = [:]

    private var artworkOrder: [String] = []
    private var heldArtworkSize: [String: Int] = [:]
    private var wantedArtworkSize: [String: Int] = [:]
    private var fetchingArtwork: Set<String> = []

    init(useCases: UseCases) {
        self.useCases = useCases
        mixes = useCases.mixUseCase.state.mixes
        phase = mixes.isEmpty ? .loading : .loaded
        useCases.mixUseCase.state.$mixes.assign(to: &$mixes)
    }

    func handleAction(_ action: MixesAction) async -> SideEffect {
        switch action {
        case .lifecycle(.viewDidAppear):
            // MIX-9: coming back to the tab keeps what was made.
            if phase == .loading { await make() }
        case .retry:
            await make()
        case .refresh:
            await make()
        case .artworkNeeded(let coverArtID, let pixelSize):
            await loadArtwork(coverArtID, pixelSize: pixelSize)
        case .mixTapped(let kind):
            if let mix = mixes.first(where: { $0.kind == kind }) { await navigateTo(.mix(mix)) }
        case .settingsTapped:
            await navigateTo(.settings)
        }

        return .none
    }

    private func make() async {
        guard !isMaking else { return }

        isMaking = true
        defer { isMaking = false }
        if mixes.isEmpty { phase = .loading }

        do {
            try await useCases.mixUseCase.makeMixes()
            phase = mixes.isEmpty ? .empty : .loaded
        } catch {
            if error.rejectsCredentials { return await reauthenticate() }

            // The mixes made before stay on screen with the error unseen, and aren't made again
            // by coming back to the tab (MIX-9); with none, the error shows.
            phase = mixes.isEmpty ? .failed(Self.message(for: error)) : .loaded
        }
    }

    /// MIX-12: the server stopped accepting the saved sign-in; back to setup to sign in again.
    private func reauthenticate() async {
        useCases.sessionUseCase.credentialsRejected()
        await useCases.appRouting.navigateToNext(from: .library, with: AppFlowData())
    }

    /// Fetches a cover at the size a card wants, as the grids do.
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
            message.isEmpty ? "The server couldn't make your mixes." : "The server said: \(message)"
        }
    }
}
